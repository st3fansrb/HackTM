#!/usr/bin/env bash

# Worker script — trimite taskuri la modelele locale Ollama
# Folosire: bash .claude/worker.sh "MODEL" "TASK" "CONTEXT"

MODEL=$1
TASK=$2
CONTEXT=$3

# Validare parametri
if [ -z "$MODEL" ] || [ -z "$TASK" ]; then
    echo "ERROR: Lipsesc parametri."
    exit 1
fi

# Path-uri
TEMP_DIR=".claude/temp"
OUTPUT_DIR=".claude/outputs"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

mkdir -p "$TEMP_DIR" "$OUTPUT_DIR"

# Context și temperatură per model
if [[ "$MODEL" == *"8b"* ]]; then
    NUM_CTX=4096
    TEMPERATURE=0.1
else
    NUM_CTX=16384
    TEMPERATURE=0.2
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Model:   $MODEL"
echo "Task:    $TASK"
echo "Time:    $TIMESTAMP"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Funcție pentru apel Ollama cu streaming
call_ollama() {
    local prompt=$1

    python3 << PYEOF
import json, urllib.request

prompt = $( echo "$prompt" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')
model = '$MODEL'
temperature = $TEMPERATURE
num_ctx = $NUM_CTX

data = json.dumps({
    'model': model,
    'prompt': prompt,
    'stream': True,
    'options': {
        'temperature': temperature,
        'num_ctx': num_ctx
    }
}).encode()

req = urllib.request.Request(
    'http://localhost:11434/api/generate',
    data=data,
    headers={'Content-Type': 'application/json'}
)

full_response = ''
try:
    with urllib.request.urlopen(req) as response:
        for line in response:
            if line:
                chunk = json.loads(line.decode())
                token = chunk.get('response', '')
                print(token, end='', flush=True)
                full_response += token
                if chunk.get('done', False):
                    break
except Exception as e:
    print(f'\nERROR: {e}')

print('')
print('__FULL_RESPONSE__')
print(full_response)
PYEOF
}

# Funcție pentru extragere cod Dart din response
extract_dart_code() {
    echo "$1" | python3 -c "
import sys, re
content = sys.stdin.read()
matches = re.findall(r'\`\`\`dart\n(.*?)\`\`\`', content, re.DOTALL)
if matches:
    print('\n'.join(matches))
"
}

# Funcție pentru flutter analyze
run_flutter_analyze() {
    local code=$1
    if [ -z "$code" ]; then
        return 0
    fi

    local temp_file="$TEMP_DIR/temp_check.dart"
    echo "$code" > "$temp_file"

    local analyze_output
    analyze_output=$(flutter analyze "$temp_file" 2>&1)
    local exit_code=$?

    rm -f "$temp_file"

    if [ $exit_code -ne 0 ]; then
        echo "$analyze_output"
        return 1
    fi
    return 0
}

# Construiește prompt
build_prompt() {
    local extra=$1
    echo "$TASK

CONTEXT:
$CONTEXT
$extra

REGULI FORMAT:
- Cod corect înainte de orice altceva — nu sacrifica corectitudinea pentru brevitate
- Format concis — fără tabele, fără emoji, fără recomandări generice
- Comentarii în cod doar unde logica e non-obvioasă
- La final adaugă obligatoriu:
CONFIDENCE: [scor 1-10]
RISK: [maxim o linie]"
}

# PRIMUL APEL
PROMPT=$(build_prompt "")
OUTPUT=$(call_ollama "$PROMPT")
RESPONSE=$(echo "$OUTPUT" | sed -n '/^__FULL_RESPONSE__$/,$ p' | tail -n +2)

if [ -z "$RESPONSE" ]; then
    echo "ERROR: Ollama nu a răspuns."
    exit 1
fi

# Flutter analyze pe primul output
DART_CODE=$(extract_dart_code "$RESPONSE")
ANALYZE_ERRORS=""

if [ -n "$DART_CODE" ]; then
    echo "🔍 Rulează flutter analyze..."
    ANALYZE_OUTPUT=$(run_flutter_analyze "$DART_CODE")
    ANALYZE_EXIT=$?

    if [ $ANALYZE_EXIT -ne 0 ]; then
        echo "⚠️  Erori găsite — retry automat..."
        ANALYZE_ERRORS="$ANALYZE_OUTPUT"

        RETRY_PROMPT=$(build_prompt "

ERORI FLUTTER ANALYZE DE CORECTAT:
$ANALYZE_ERRORS

Corectează codul astfel încât flutter analyze să treacă fără erori.")

        RETRY_OUTPUT=$(call_ollama "$RETRY_PROMPT")
        RETRY_RESPONSE=$(echo "$RETRY_OUTPUT" | sed -n '/^__FULL_RESPONSE__$/,$ p' | tail -n +2)

        if [ -n "$RETRY_RESPONSE" ]; then
            RETRY_DART=$(extract_dart_code "$RETRY_RESPONSE")
            RETRY_ANALYZE=$(run_flutter_analyze "$RETRY_DART")
            RETRY_EXIT=$?

            if [ $RETRY_EXIT -ne 0 ]; then
                echo "❌ ESCALADARE — erori persistă după retry"
                echo "ESCALATE_ANALYZE" > "$TEMP_DIR/escalate_flag"
                RESPONSE=$RETRY_RESPONSE
            else
                echo "✅ Retry reușit — erori corectate"
                RESPONSE=$RETRY_RESPONSE
                rm -f "$TEMP_DIR/escalate_flag"
            fi
        fi
    else
        echo "✅ Flutter analyze — fără erori"
        rm -f "$TEMP_DIR/escalate_flag"
    fi
fi

# Salvează outputul final
OUTPUT_FILE="$OUTPUT_DIR/${MODEL//:/\_}_${TIMESTAMP}.md"
echo "# Task: $TASK" > "$OUTPUT_FILE"
echo "**Model:** $MODEL" >> "$OUTPUT_FILE"
echo "**Time:** $TIMESTAMP" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"
echo "$RESPONSE" >> "$OUTPUT_FILE"

echo "$RESPONSE"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Output salvat: $OUTPUT_FILE"

# Confidence score
CONFIDENCE=$(echo "$RESPONSE" | grep -o "CONFIDENCE: [0-9]*" | grep -o "[0-9]*")

if [ -n "$CONFIDENCE" ]; then
    echo "Confidence: $CONFIDENCE/10"
    if [ "$CONFIDENCE" -lt 7 ]; then
        echo "⚠️  ESCALADARE — confidence sub 7"
        echo "ESCALATE" > "$TEMP_DIR/escalate_flag"
    else
        echo "✅ Output acceptabil"
    fi
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"