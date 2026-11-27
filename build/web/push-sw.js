self.addEventListener('push', (event) => {
  let message = {};
  try { message = event.data ? event.data.json() : {}; } catch (_) {}
  const notification = message.notification || message;
  const title = notification.title || message.title || 'Budget payment reminder';
  const body = notification.body || message.body || 'You have a payment due.';
  const tag = message.tag || 'budget-payment';
  event.waitUntil(self.registration.showNotification(title, {
    body, tag, icon: '/icons/budget-icon.svg', badge: '/icons/budget-icon.svg',
    data: { url: message.url || '/' },
  }));
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const url = new URL(event.notification.data?.url || '/', self.location.origin).href;
  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then((windows) => {
      for (const client of windows) {
        if (client.url.startsWith(self.location.origin) && 'focus' in client) return client.focus();
      }
      return clients.openWindow(url);
    })
  );
});