(function () {
  'use strict';

  var _stream     = null;
  var _codeReader = null;
  var _torchOn    = false;
  var _startToken = 0;

  window.frigDebug = function (msg) {
    if (typeof window.onDebugMessage === 'function') {
      window.onDebugMessage(msg);
    }
  };

  function _initReader() {
    if (typeof ZXing === 'undefined') {
      frigDebug('ZXing: NOT available');
      console.warn('[Frigo] ZXing not available — camera scan will not work.');
      return;
    }
    const hints = new Map();
    hints.set(ZXing.DecodeHintType.POSSIBLE_FORMATS, [
      ZXing.BarcodeFormat.EAN_13,
      ZXing.BarcodeFormat.EAN_8,
      ZXing.BarcodeFormat.UPC_A,
      ZXing.BarcodeFormat.UPC_E,
      ZXing.BarcodeFormat.CODE_128,
    ]);
    hints.set(ZXing.DecodeHintType.TRY_HARDER, true);
    _codeReader = new ZXing.BrowserMultiFormatReader(hints);
    frigDebug('ZXing: BrowserMultiFormatReader ready');
  }

  _initReader();

  function _report(rawValue) {
    if (typeof window.onBarcodeScanned === 'function') {
      window.onBarcodeScanned(rawValue);
    }
  }

  window.startScanner = function () {
    var token = ++_startToken;

    var streamPromise = navigator.mediaDevices.getUserMedia({
      video: { facingMode: 'environment', width: { ideal: 1280 }, height: { ideal: 720 } }
    });

    (function tryMount() {
      if (token !== _startToken) return;
      var el = document.getElementById('qr-reader');
      if (!el || el.offsetWidth < 10 || el.offsetHeight < 10) {
        setTimeout(tryMount, 150);
        return;
      }

      streamPromise
        .then(function (stream) {
          if (token !== _startToken) {
            stream.getTracks().forEach(function (t) { t.stop(); });
            return;
          }
          _stream  = stream;
          _torchOn = false;

          var video = document.createElement('video');
          video.setAttribute('playsinline', '');
          video.setAttribute('autoplay', '');
          video.setAttribute('muted', '');
          video.style.cssText = 'width:100%;height:100%;object-fit:cover;display:block;';
          video.srcObject = stream;

          el.innerHTML = '';
          el.appendChild(video);

          video.play()
            .then(function () {
              if (token !== _startToken) return;
              if (!_codeReader) { frigDebug('ZXing reader is null'); return; }

              frigDebug('ZXing decodeFromStream started');

              _codeReader.decodeFromStream(stream, video, function (result, error) {
                if (result) {
                  frigDebug('detected: ' + result.getText());
                  _report(result.getText());
                }
                if (error && !(error instanceof ZXing.NotFoundException)) {
                  frigDebug('ZXing error: ' + error.message);
                }
              });
            })
            .catch(function (err) { console.warn('[Frigo] video.play() error:', err); });
        })
        .catch(function (err) { console.warn('[Frigo] getUserMedia error:', err); });
    })();
  };

  window.stopScanner = function () {
    _startToken++;
    if (_stream) {
      _stream.getTracks().forEach(function (t) { t.stop(); });
      _stream = null;
    }
    if (_codeReader) {
      _codeReader.reset();
    }
    _torchOn = false;
  };

  window.toggleTorch = function () {
    if (!_stream) return;
    var track = _stream.getVideoTracks()[0];
    if (!track) return;
    _torchOn = !_torchOn;
    track.applyConstraints({ advanced: [{ torch: _torchOn }] })
      .catch(function (err) {
        console.warn('[Frigo] Torch not supported:', err);
        _torchOn = !_torchOn;
      });
  };

})();
