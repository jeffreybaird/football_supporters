// Progressive enhancement for the language drawer (views/_language_drawer.erb).
// The <details> element already opens/closes on click and keyboard with no JS;
// this only adds the niceties a native <details> lacks: close on Escape, close on
// a click outside the panel, a working Close button, and moving focus into the
// sheet when it opens so keyboard users land inside it. Thin DOM glue, no logic.
(function () {
  "use strict";

  var drawer = document.querySelector("[data-langdrawer]");
  if (!drawer) return;

  var sheet = drawer.querySelector("[data-langdrawer-sheet]");
  var trigger = drawer.querySelector("summary");
  var closeBtn = drawer.querySelector("[data-langdrawer-close]");

  function close() {
    if (!drawer.open) return;
    drawer.open = false;
    if (trigger) trigger.focus();
  }

  // When it opens, move focus to the first language option inside the panel.
  drawer.addEventListener("toggle", function () {
    if (!drawer.open) return;
    var first = drawer.querySelector(".langdrawer__option");
    if (first) first.focus();
  });

  document.addEventListener("keydown", function (e) {
    if (e.key === "Escape" && drawer.open) {
      e.preventDefault();
      close();
    }
  });

  // A click on the dimmed backdrop (the sheet itself, outside the panel) closes.
  if (sheet) {
    sheet.addEventListener("click", function (e) {
      if (e.target === sheet) close();
    });
  }

  if (closeBtn) closeBtn.addEventListener("click", close);
})();
