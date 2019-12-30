function init() {
  document.getElementById("github").onclick = function() {
    location.href = "https://github.com/myneur/late";
  };
  document.getElementById("ciq").onclick = function() {
    location.href =
      "https://apps.garmin.com/en-US/apps/3532114a-c93c-447a-bc8e-25999ea599fc";
  };
  document.getElementById("behance").onclick = function() {
    location.href =
      "www.behance.net/gallery/33752138/Smart-watch-face-navigating-through-the-day";
  };

  https: $("#device-screenshots").cycle({
    fx: "fade",
    speed: 1500,
    timeout: 5000
  });
}
