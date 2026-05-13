# Orchestration Layer — citește PRIMUL

## Modele disponibile
- **qwen3.6:35b** — main worker (MoE, 24GB, 256K context, agentic coding)
- **qwen3:8b** — fast worker (5GB, boilerplate și taskuri simple)
- **qwen2.5-coder:32b** — backup worker (20GB, pe disk, nu se folosește implicit)

## Vault Obsidian
- Path: ~/Documents/FrigoBrain
- La începutul fiecărei sesiuni citește:
  - Frigo/Decisions/stack.md
  - Frigo/Decisions/ (toate fișierele)
  - Sessions/ (ultimele 3 sesiuni)
- La sfârșitul sesiunii rulează automat: python3 .claude/memory.py
- La sfârșitul fiecărui task important scrie în Frigo/Decisions/
- La sfârșitul fiecărei sesiuni scrie în Sessions/

## Context per feature — Opțiunea 3 + safety net
Haiku citește fișierele per feature + urmărește importurile recursive.

### Fișiere de start per feature:
- pantry/ → lib/features/pantry/ + lib/shared/widgets/ + lib/core/
- auth/ → lib/features/auth/ + lib/core/router/
- meal_planner/ → lib/features/meal_planner/ + lib/shared/providers/
- shopping_list/ → lib/features/shopping_list/ + lib/shared/providers/
- nutrition/ → lib/features/nutrition/ + lib/core/constants/

### Safety net — verificări obligatorii:
1. După citire: există referințe în codul citit către fișiere necitite?
   DA → Haiku citește și acele fișiere înainte să continue
   NU → continuă

2. Taskul implică mai mult de un feature?
   DA → Haiku citește fișierele relevante din toate feature-urile implicate
   NU → continuă

3. După output model: imports către fișiere care nu erau în context?
   DA → Haiku citește fișierele lipsă → retry o singură dată
   NU → review normal

## Mod curent: HACKTM SPRINT (până pe 16 mai)
- Prioritate maximă: funcționalitate demo > cod perfect
- Nu refactoriza ce merge deja
- Nu instala pachete noi fără să întrebi explicit
- Orice task nou → întreabă dacă e critic pentru demo sau poate aștepta
- Dacă un feature merge 80% → lasă-l, treci mai departe

## Demo data — obligatoriu
Orice feature implementat trebuie să aibă date demo pre-populate.
Nu lăsa ecrane goale. Dacă implementezi un feature → există și date
demo vizibile imediat fără acțiuni din partea userului.

## Checklist înainte de orice commit
- [ ] Testat în Chrome mobile, nu doar Flutter desktop
- [ ] Loading state vizibil pe toate operațiile async
- [ ] Error state vizibil
- [ ] Demo data prezentă și vizibilă
- [ ] Nu există print() rămase în cod
- [ ] flutter analyze rulat și fără erori
## Când primești un request

### Dacă e vag — întreabă înainte de orice:
- Ce feature exact? (nu presupune)
- Afectează module existente? Care?
- Există o decizie arhitecturală relevantă în Obsidian?
- Prioritate: HackTM demo (înainte de 16 mai) sau calitate pe termen lung?

### Dacă e clar — înainte să execuți:
1. Citește fișierele relevante din repo (delegă la Haiku)
2. Citește deciziile relevante din Obsidian (delegă la Haiku)
3. Estimează dimensiunea taskului
4. Descompune în subtaskuri dacă e necesar
5. Decide routing pentru fiecare subtask

## Routing — ce model face ce

### Haiku (citit și parsing — nu generează cod niciodată)
- Citește fișiere din repo
- Citește și extrage din Obsidian
- Parsează outputul modelelor locale
- Pasează context structurat înapoi

### qwen3:8b — fast worker
- Widgets Flutter boilerplate
- Firebase queries simple
- Models, DTOs, structuri repetitive
- Teste unitare
- Refactorizare mecanică
- Review output propriu (confidence score)

### qwen3.6:35b — main worker
- Logică de business (expirare, NutriScore, meal planning)
- Integrări Firebase complexe
- Bug fixing cu context larg
- Review output qwen3:8b
- Orice task unde 8b a dat output slab

### Claude Sonnet (tu) — orchestrator și escaladare
- Decizii arhitecturale normale
- Review final înainte de commit
- Când main worker a eșuat de două ori
- Taskuri care afectează mai mult de un modul

### Claude Opus — doar pentru restructurare fundamentală
- Când arhitectura trebuie regândită complet
- Schimbări de direcție majore ale produsului
- Când Sonnet identifică o problemă mai adâncă
- Folosit rar — nu pentru bug-uri obișnuite

## Exemple concrete de routing — obligatoriu respectate

### ÎNTOTDEAUNA la modele locale via worker.sh:
- "Scrie widget-ul X" → qwen3:8b
- "Generează teste pentru Y" → qwen3:8b  
- "Implementează logica de Z" → qwen3.6:35b
- "Scrie queries Firestore pentru W" → qwen3.6:35b
- "Refactorizează fișierul X" → qwen3:8b
- "Adaugă seed data pentru demo" → qwen3.6:35b

### ÎNTOTDEAUNA direct Claude Code, fără modele locale:
- Bug fix simplu cu cauza clară
- Modificare în fișier existent sub 10 linii
- Decizie arhitecturală
- Review final înainte de commit
- Orice task care afectează mai mult de 2 fișiere simultan

### SEMN DE ÎNTREBARE — întreabă userul:
- Task ambiguu care poate fi ori simplu ori complex
- Feature nou care implică atât generare cât și integrare

## Cum trimiți taskuri la modele locale
```bash
bash .claude/worker.sh "qwen3:8b" "TASK" "CONTEXT"
bash .claude/worker.sh "qwen3.6:35b" "TASK" "CONTEXT"
```

## Review chain — obligatoriu
- Output qwen3:8b → qwen3.6:35b face review
- Output qwen3.6:35b → Sonnet face review
- Output cu confidence < 7/10 → escaladare automată la nivelul următor
- Al doilea retry eșuat → escaladare obligatorie

## Review asimetric — regulă fixă
- qwen3:8b NU face review la outputul qwen3.6:35b niciodată
- qwen3.6:35b face review doar la outputul qwen3:8b
- Sonnet face review final la orice merge în codebase

## Task sizing
- Sub 50 linii output estimat → trimite direct la model
- Peste 50 linii → descompune în subtaskuri mai mici

## Paralelism
- Task B depinde de Task A → secvențial obligatoriu
- Taskuri independente → paralel (8b și 35b simultan)
- Grupează taskurile per model — minimizează swap-urile între modele

## Escaladare
| Situație | Acțiune |
|---|---|
| qwen3:8b eșuează | → qwen3.6:35b preia |
| qwen3.6:35b eșuează | → Sonnet preia direct |
| Al doilea retry eșuat | → Sonnet preia direct |
| Decizie arhitecturală | → Sonnet obligatoriu |
| Bug recurent care indică problemă arhitecturală | → Sonnet evaluează, Opus dacă e restructurare |
| Restructurare fundamentală | → Opus |

## Format output modele locale
- Cod corect înainte de orice altceva 
- nu sacrifica corectitudinea pentru brevitate
- Format concis — fără tabele, fără emoji, fără recomandări generice
- Fără tabele explicative
- Fără secțiuni de recomandări generice
- Comentarii în cod doar unde logica e non-obvioasă
- Fără emoji în răspunsuri tehnice

## Confidence score
La finalul fiecărui task, modelul local răspunde și cu:
- Scor 1-10 cât de sigur e pe output
- Ce risc există să fie greșit
Sub 7 → escaladare automată fără retry

## Learning loop — după fiecare sesiune
Haiku scrie automat în Obsidian:
- Models/MoE-log sau Models/Dense-log: ce a mers bine/rău
- Sessions/: taskuri executate, escaladări, pattern-uri de erori
- Frigo/Errors/: bug-uri recurente și cauza root
# Frigo — Claude Code Instructions (HackTM Build)

## Context
Aplicație mobilă Flutter PWA de food management pentru piața românească.
Target competiție: HackTM — categorii Best Startup + Best Impact.
Build scope: demo funcțional, nu producție. Prioritate = wow factor vizual + features care funcționează live pe scenă.

## Stack tehnic — FIXED, nu schimba fără instrucțiuni explicite
- **Frontend:** Flutter (Dart) — compilat ca PWA
- **Database:** Firebase Firestore (NoSQL)
- **Auth:** Firebase Auth (email + Google Sign-In)
- **State management:** Riverpod
- **Navigare:** GoRouter
- **Barcode scanning:** `mobile_scanner`
- **AI chat:** Anthropic Claude API (claude-haiku-3 pentru latență mică)
- **Target:** PWA — testează mereu în Chrome mobile, nu doar în Flutter desktop

## Referință vizuală
`reference/mockup.html` — mockup HTML al UI-ului. 
Folosește-l ca referință pentru culori, layout și feeling general.
Nu modifica acest fișier.

## Design System — respectă întotdeauna
- **Culoare primară:** verde vibrant (`#2ECC71` placeholder — va fi rafinat ulterior)
- **Accente:** portocaliu / galben energic
- **Fonturi:** rotunjite — Google Fonts `Nunito` sau `Poppins`
- **Feeling:** tânăr, energic, curat — nu corporate, nu minimalist plictisitor
- **Status expirare:**
  - Verde `#2ECC71` = fresh (> 7 zile)
  - Galben `#F39C12` = use soon (1–7 zile)
  - Roșu `#E74C3C` = expirat sau azi
- **Scoring nutrițional:**
  - A = `#27AE60`
  - B = `#2ECC71`
  - C = `#F39C12`
  - D = `#E74C3C`

## Structura folderelor — respectă exact
```
lib/
├── main.dart
├── firebase_options.dart
├── core/
│   ├── constants/        # AppColors, AppStrings, NutriScoring
│   ├── theme/            # AppTheme cu Nunito/Poppins
│   └── router/           # GoRouter — toate rutele aici
├── features/
│   ├── auth/
│   │   └── presentation/ # LoginScreen, OnboardingScreen
│   ├── pantry/
│   │   ├── data/         # Firestore calls, barcode_products.dart
│   │   ├── domain/       # FoodItem model
│   │   └── presentation/ # PantryScreen, AddItemScreen, ItemCard
│   ├── nutrition/
│   │   ├── domain/       # NutriScore model + calcul A/B/C/D
│   │   └── presentation/ # NutriScoreBadge widget
│   ├── meal_planner/
│   │   ├── data/         # ClaudeService
│   │   └── presentation/ # ChatScreen, MessageBubble, AddToListButton
│   └── shopping_list/
│       ├── data/         # Firestore calls
│       └── presentation/ # ShoppingListScreen, ShoppingItemTile
├── shared/
│   ├── widgets/          # AppButton, AppCard, StatusBadge, BottomNav
│   └── providers/        # pantryProvider, shoppingListProvider, chatProvider
```

## Firestore Schema
```
users/{userId}
  - email: string
  - displayName: string
  - householdSize: int
  - dietaryPreferences: string[]
  - createdAt: timestamp

users/{userId}/pantry/{itemId}
  - name: string
  - category: string        # dairy | meat | vegetables | fruits | grains | other
  - quantity: double
  - unit: string            # kg | g | L | ml | buc
  - expiryDate: timestamp
  - barcode: string?
  - calories: double?       # per 100g
  - sugar: double?          # per 100g
  - fat: double?            # per 100g
  - nutriScore: string?     # A | B | C | D — calculat automat
  - addedAt: timestamp

users/{userId}/shopping_list/{itemId}
  - name: string
  - quantity: double?
  - unit: string?
  - checked: bool
  - source: string          # "ai" | "manual" | "meal_plan"
  - addedAt: timestamp
```

## Produse demo barcode (barcode_products.dart) — hardcodat, nu fetch extern
```dart
const Map<String, Map<String, dynamic>> kDemoProducts = {
  '5941196004406': {'name': 'Lapte Zuzu 1.5%', 'category': 'dairy', 'unit': 'L', 'quantity': 1.0, 'calories': 46.0, 'sugar': 4.8, 'fat': 1.5},
  '5941196004413': {'name': 'Lapte Zuzu 3.5%', 'category': 'dairy', 'unit': 'L', 'quantity': 1.0, 'calories': 62.0, 'sugar': 4.7, 'fat': 3.5},
  '5941197001139': {'name': 'Iaurt Danone Natural', 'category': 'dairy', 'unit': 'g', 'quantity': 125.0, 'calories': 55.0, 'sugar': 5.0, 'fat': 2.8},
  '5941348001283': {'name': 'Brânză Telemea Dorna', 'category': 'dairy', 'unit': 'g', 'quantity': 300.0, 'calories': 264.0, 'sugar': 0.5, 'fat': 21.0},
  '4008258720074': {'name': 'Ouă Proaspete L (10 buc)', 'category': 'other', 'unit': 'buc', 'quantity': 10.0, 'calories': 143.0, 'sugar': 0.4, 'fat': 9.5},
  '5941148012548': {'name': 'Piept Pui Clasic', 'category': 'meat', 'unit': 'kg', 'quantity': 0.8, 'calories': 165.0, 'sugar': 0.0, 'fat': 3.6},
  '5000112548167': {'name': 'Coca-Cola 2L', 'category': 'other', 'unit': 'L', 'quantity': 2.0, 'calories': 42.0, 'sugar': 10.6, 'fat': 0.0},
  '5941348009036': {'name': 'Pâine Albă Vel Pitar', 'category': 'grains', 'unit': 'g', 'quantity': 500.0, 'calories': 255.0, 'sugar': 3.5, 'fat': 2.1},
  '5941197002038': {'name': 'Unt Président 82%', 'category': 'dairy', 'unit': 'g', 'quantity': 200.0, 'calories': 745.0, 'sugar': 0.6, 'fat': 82.0},
  '3017620422003': {'name': 'Nutella 400g', 'category': 'other', 'unit': 'g', 'quantity': 400.0, 'calories': 539.0, 'sugar': 57.5, 'fat': 30.9},
};
```

## NutriScore — logica de calcul
```dart
String calculateNutriScore(double? calories, double? sugar, double? fat) {
  if (calories == null || sugar == null || fat == null) return 'N/A';
  int points = 0;
  if (calories > 400) points += 3;
  else if (calories > 200) points += 2;
  else if (calories > 100) points += 1;
  if (sugar > 20) points += 3;
  else if (sugar > 10) points += 2;
  else if (sugar > 5) points += 1;
  if (fat > 20) points += 3;
  else if (fat > 10) points += 2;
  else if (fat > 5) points += 1;
  if (points <= 2) return 'A';
  if (points <= 4) return 'B';
  if (points <= 6) return 'C';
  return 'D';
}
```

## AI Chat — Claude API
- **Model:** `llama-3.1-8b-instant` (Groq — gratuit, OpenAI-compatible API)
- **Base URL:** `https://api.groq.com/openai/v1`
- **Upgrade rapid:** schimbă doar baseUrl + apiKey + model string pentru alt provider
- **Max istoric trimis:** ultimele 10 mesaje (nu toată conversația)
- **Context injectat la fiecare mesaj:** lista produselor din pantry cu name, quantity, unit, daysUntilExpiry
- **System prompt fix:**
```
Ești Frigo AI, asistentul inteligent pentru reducerea risipei alimentare.
Ai acces la pantry-ul utilizatorului. Când sugerezi rețete, prioritizează
ÎNTOTDEAUNA ingredientele care expiră cel mai curând. Când utilizatorul
întreabă ce să gătească, răspunde cu o rețetă concretă și realistă.
Când identifici produse lipsă dintr-o rețetă, listează-le pe linii separate
prefixate cu '🛒 Lipsește:' pentru fiecare produs în parte.
```
- **Parse pentru shopping:** extrage liniile cu "🛒 Lipsește:" — butonul "Adaugă în listă" le trimite în shopping_list cu source: "ai"

## Navigare — bottom nav cu 5 tabs
```
0: Pantry        (icon: kitchen)
1: Scanner       (icon: qr_code_scanner)
2: AI Chat       (icon: auto_awesome — centru, mai mare, accent color)
3: Shopping List (icon: shopping_cart)
4: Profil        (icon: person)
```

## Convenții de cod
- Variabile și comentarii în engleză, UI strings în română
- `snake_case` fișiere, `camelCase` variabile, `PascalCase` clase
- Nu folosi `setState` — exclusiv Riverpod
- Nu folosi `Navigator.push` — exclusiv GoRouter
- Try/catch pe toate apelurile Firestore și Claude API
- Arată întotdeauna loading indicator și error state

## Ce să NU faci niciodată
- Nu instala pachete noi fără să întrebi
- Nu face fetch extern pentru barcode — folosește kDemoProducts
- Nu trimite tot istoricul la Claude API — max 10 mesaje
- Nu uita loading states și error states — juriul vede bug-urile

## Ordinea de build
1. Setup Flutter + Firebase + GoRouter + tema vizuală (Nunito/Poppins + culori)
2. Auth (email sau Google)
3. Pantry screen + AddItem manual + ItemCard cu expiry badge color-coded
4. Barcode scanner cu kDemoProducts
5. NutriScore badge pe ItemCard
6. AI Chat cu Claude API + buton "Adaugă în listă"
7. Shopping List screen
8. Profil / Setări
9. Polish vizual + demo data pre-încărcată pentru prezentare
