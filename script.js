
const htmlForm = document.getElementById('form')
const output = document.getElementById('output');

htmlForm.onsubmit = async (error)=> {
  error.preventDefault();
  output.innerHTML = "<li>Analyzing…</li>";

  const formData = new FormData(htmlForm);
  const response = await fetch('/analyze-page', { method:'POST', body: formData });

  if (!response.ok) {
    output.innerHTML = `<li>Error: ${response.status}</li>`;
    return;
  }

  const j = await response.json();
  output.innerHTML = "";

  (j.notes||["No notes returned"]).forEach(n=>{
    const li = document.createElement('li'); li.textContent = n; output.append(li);
  });
};

async function runAnalysis() {
  resultsEl.textContent = "Analyzing…";
  const body = {
    url: urlInput.value.trim(),
    goals: goalsInput.value.trim() || null
  };

  try {
    const res = await fetch("/analyze-page", {
      method: "POST",
      headers: {"Content-Type": "application/json"},
      body: JSON.stringify(body)
    });

    const payload = await res.json();

    if (!res.ok) {
      // Show friendly message from server
      resultsEl.textContent = `Error: ${payload.detail || 'Something went wrong.'}`;
      return;
    }

    // success path
    const data = typeof payload.data === "string" ? JSON.parse(payload.data) : payload.data;

    // render your JSON results...
    resultsEl.textContent = JSON.stringify(data, null, 2);

  } catch (err) {
    resultsEl.textContent = `Network or parse error: ${err.message || err}`;
  }
}

