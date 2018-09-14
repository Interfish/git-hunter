function showDetails(event) {
  var content = event.currentTarget.getElementsByClassName("content")[0]
  var mask = document.getElementById("mask");
  var repoDetails = document.getElementById("show-details");
  var lastClicked = document.querySelector('.last-clicked');
  if(lastClicked){
    lastClicked.classList.remove("last-clicked");
  }
  event.currentTarget.classList.add("last-clicked");
  repoDetails.innerHTML = content.innerHTML;
  repoDetails.setAttribute("style", "display: block;");
  mask.setAttribute("style", "display: block;");
  repoDetails.animate([
    {opacity: "0"},
    {opacity: "1"}
  ], {
    duration: 200
  });
  mask.animate([
    {opacity: "0"},
    {opacity: "1"}
  ], {
    duration: 200
  });
}

function closeDetails(event) {
  var mask = document.getElementById("mask");
  var repoDetails = document.getElementById("show-details");
  repoDetails.innerHTML = null;
  repoDetails.setAttribute("style", "display: none;");
  mask.setAttribute("style", "display: none;");
}