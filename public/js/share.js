// Progressive enhancement for the shared-result share block. Thin DOM glue only:
// wires the Web Share API (with a clipboard fallback) onto the server-rendered
// controls, located by data-testid. No business logic here.
(function () {
  "use strict";

  function testid(id) {
    return document.querySelector('[data-testid="' + id + '"]');
  }

  var input = testid("share-url");
  if (!input) return;

  var copyBtn = testid("share-copy");
  var shareBtn = testid("share-native");
  var status = testid("share-status");
  var url = input.value;
  var text = input.getAttribute("data-share-text") || document.title;

  function say(message) {
    if (status) status.textContent = message;
  }

  function copy() {
    if (navigator.clipboard && navigator.clipboard.writeText) {
      navigator.clipboard.writeText(url).then(
        function () { say("Link copied"); },
        function () { input.select(); say("Press Ctrl/Cmd+C to copy"); }
      );
    } else {
      input.select();
      say("Press Ctrl/Cmd+C to copy");
    }
  }

  if (copyBtn) copyBtn.addEventListener("click", copy);

  if (shareBtn) {
    if (navigator.share) {
      shareBtn.addEventListener("click", function () {
        navigator.share({ title: document.title, text: text, url: url }).catch(function () {});
      });
    } else {
      // No Web Share API (most desktops) — fall back to copying the link.
      shareBtn.addEventListener("click", copy);
    }
  }
})();
