// Blurb text helpers shared by the client view (views/quiz/index.erb).
//
// firstSentence mirrors App#first_sentence in app.rb — the two must agree,
// because the same blurb is trimmed here (client-rendered alternates and the
// profile league rows) and in Ruby (the server-rendered /q/:slug pages and OG
// descriptions).
//
// Splitting on ". " breaks an abbreviation like "St. Louis" into its own chunk,
// so a chunk that ends in an abbreviation (or an initial like "J") is folded
// back in rather than treated as the end of the sentence. A sentence shorter
// than MIN_WORDS is folded on too: some blurbs open on a punchy fragment
// ("Neverkusen.") that says nothing on its own.
(function (global) {
  var ABBREVIATIONS = ["St", "Mt", "Ft", "Dr", "Mr", "Mrs", "Ms", "Jr", "Sr", "Co", "Inc", "No", "vs"];
  var MIN_WORDS = 5;

  function keepFolding(text) {
    var last = (text.match(/\S+$/) || [""])[0];
    if (ABBREVIATIONS.indexOf(last) !== -1 || /^[A-Z]$/.test(last)) return true;
    return text.split(/\s+/).length < MIN_WORDS;
  }

  function firstSentence(text) {
    var sentence = text
      .split(". ")
      .reduce(function (acc, chunk) {
        return keepFolding(acc) ? acc + ". " + chunk : acc;
      });
    return sentence + ".";
  }

  global.firstSentence = firstSentence;
  if (typeof module !== "undefined" && module.exports) module.exports = { firstSentence: firstSentence };
})(typeof globalThis !== "undefined" ? globalThis : this);
