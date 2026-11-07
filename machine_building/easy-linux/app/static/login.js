const username = document.querySelector('[name="username"]');
const directoryHint = document.querySelector('#directory-hint');

if (username && directoryHint) {
  username.addEventListener('blur', async () => {
    const value = username.value.trim();
    if (value.length < 2) {
      directoryHint.textContent = '';
      return;
    }

    directoryHint.textContent = 'Checking reporting directory…';
    try {
      const response = await fetch(`/api/v1/directory/search?name=${encodeURIComponent(value)}`);
      const users = await response.json();
      directoryHint.textContent = users.length
        ? `${users.length} reporting account${users.length === 1 ? '' : 's'} matched.`
        : 'No reporting account matched.';
    } catch (_) {
      directoryHint.textContent = 'Directory lookup is temporarily unavailable.';
    }
  });
}
