if(window.navigator && navigator.serviceWorker) {
  navigator.serviceWorker.getRegistrations().then(function(registrations) {
    for(let registration of registrations) {
      registration.unregister();
    }
  });
}

if ('caches' in window) {
  caches.keys().then(function(keyList) {
    for(let key of keyList) {
      if (key.startsWith('gatsby')) {
        caches.delete(key);
      }
    };
  })
}
