const output = document.getElementById("output");
const result = document.getElementById("result");
const button = document.getElementById("getblockchaininfo");

function getblockchaininfo_run() {
  cockpit.spawn(["bitcoin-cli", "getblockchaininfo"])
    .stream(getblockchaininfo_output)
    .then(getblockchaininfo_success)
    .catch(getblockchaininfo_fail);

  result.textContent = "";
  output.textContent = "";
}

function getblockchaininfo_success() {
  result.style.color = "black";
  result.textContent = "success";
}

function getblockchaininfo_fail() {
  result.style.color = "red";
  result.textContent = "fail";
}

function getblockchaininfo_output(data) {
  output.append(document.createTextNode(data));
}

// Connect the button to starting the "ping" process
button.addEventListener("click", getblockchaininfo_run);

// Send a 'init' message.  This tells integration tests that we are ready to go
cockpit.transport.wait(function () { });
