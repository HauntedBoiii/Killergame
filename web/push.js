function _urlBase64ToUint8Array(base64String) {
  var padding = '='.repeat((4 - (base64String.length % 4)) % 4);
  var base64 = (base64String + padding).replace(/-/g, '+').replace(/_/g, '/');
  var rawData = window.atob(base64);
  var outputArray = new Uint8Array(rawData.length);
  for (var i = 0; i < rawData.length; ++i) outputArray[i] = rawData.charCodeAt(i);
  return outputArray;
}

window.getNotificationPermission = function () {
  if (!('Notification' in window)) return 'unsupported';
  return Notification.permission;
};

window.isRunningAsPwa = function () {
  return window.matchMedia('(display-mode: standalone)').matches
    || window.navigator.standalone === true;
};

window.requestPushSubscription = function (vapidPublicKey) {
  return new Promise(function (resolve) {
    if (!('serviceWorker' in navigator) || !('PushManager' in window)) return resolve(null);
    if (Notification.permission === 'denied') return resolve(null);

    Notification.requestPermission().then(function (permission) {
      if (permission !== 'granted') return resolve(null);

      navigator.serviceWorker.register('/push-sw.js').then(function (registration) {
        navigator.serviceWorker.ready.then(function () {
          registration.pushManager.getSubscription().then(function (existing) {
            var doSubscribe = function () {
              registration.pushManager.subscribe({
                userVisibleOnly: true,
                applicationServerKey: _urlBase64ToUint8Array(vapidPublicKey),
              }).then(function (sub) {
                resolve(JSON.stringify(sub));
              }).catch(function (err) {
                console.error('[push] subscribe failed:', err);
                resolve(null);
              });
            };
            if (existing) {
              existing.unsubscribe().then(doSubscribe).catch(doSubscribe);
            } else {
              doSubscribe();
            }
          });
        });
      }).catch(function () { resolve(null); });
    });
  });
};
