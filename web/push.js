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
    if (!('serviceWorker' in navigator) || !('PushManager' in window)) {
      return resolve('ERROR:push_not_supported');
    }
    if (Notification.permission === 'denied') {
      return resolve('ERROR:permission_denied');
    }

    Notification.requestPermission().then(function (permission) {
      if (permission !== 'granted') {
        return resolve('ERROR:permission_not_granted:' + permission);
      }

      var doSubscribe = function (registration) {
        var subscribe = function () {
          registration.pushManager.subscribe({
            userVisibleOnly: true,
            applicationServerKey: _urlBase64ToUint8Array(vapidPublicKey),
          }).then(function (sub) {
            resolve(JSON.stringify(sub));
          }).catch(function (err) {
            console.error('[push] subscribe failed:', err);
            resolve('ERROR:subscribe_failed:' + (err.message || err.toString()));
          });
        };
        registration.pushManager.getSubscription().then(function (existing) {
          if (existing) {
            existing.unsubscribe().then(subscribe).catch(subscribe);
          } else {
            subscribe();
          }
        });
      };

      // Use existing SW registration if available (avoids conflict with Flutter SW)
      navigator.serviceWorker.getRegistration('/').then(function (existing) {
        if (existing) {
          doSubscribe(existing);
        } else {
          navigator.serviceWorker.register('/push-sw.js').then(function (reg) {
            navigator.serviceWorker.ready.then(function () { doSubscribe(reg); });
          }).catch(function (err) {
            console.error('[push] SW register failed:', err);
            resolve('ERROR:sw_register_failed:' + (err.message || err.toString()));
          });
        }
      });
    });
  });
};
