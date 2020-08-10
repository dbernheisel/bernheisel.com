import topbar from "topbar"

topbar.config({
  barThickness: 2,
  shadowBlur: 5,
  barColors: ["#F56565", "#9B2C2C"],
})

let topbarDelay = null;

// Show progress bar on live navigation and form submits
window.addEventListener("phx:page-loading-start", _info => {
  clearTimeout(topbarDelay);
  topbarDelay = setTimeout(() => topbar.show(), 200);
})
window.addEventListener("phx:page-loading-stop", _info => {
  clearTimeout(topbarDelay);
  topbar.hide();
})
