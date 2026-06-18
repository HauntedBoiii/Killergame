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

      var doSubscribe = function (reg) {
        var subscribe = function () {
          reg.pushManager.subscribe({
            userVisibleOnly: true,
            applicationServerKey: _urlBase64ToUint8Array(vapidPublicKey),
          }).then(function (sub) {
            resolve(JSON.stringify(sub));
          }).catch(function (err) {
            console.error('[push] subscribe failed:', err);
            resolve('ERROR:subscribe_failed:' + (err.message || err.toString()));
          });
        };
        reg.pushManager.getSubscription().then(function (existing) {
          if (existing) {
            existing.unsubscribe().then(subscribe).catch(subscribe);
          } else {
            subscribe();
          }
        });
      };

      // First clean up any old subscriptions from other SW registrations
      navigator.serviceWorker.getRegistrations().then(function (registrations) {
        return Promise.all(registrations.map(function (r) {
          return r.pushManager.getSubscription().then(function (sub) {
            if (sub) return sub.unsubscribe();
          });
        }));
      }).then(function () {
        // Register dedicated push SW at its own scope — no conflict with Flutter SW
        navigator.serviceWorker.register('/push-sw.js', { scope: '/push-notifications/' })
          .then(function (reg) {
            var sw = reg.installing || reg.waiting || reg.active;
            if (reg.active) {
              doSubscribe(reg);
            } else if (sw) {
              sw.addEventListener('statechange', function () {
                if (this.state === 'activated') doSubscribe(reg);
              });
            } else {
              resolve('ERROR:sw_no_worker');
            }
          })
          .catch(function (err) {
            console.error('[push] SW register failed:', err);
            resolve('ERROR:sw_register_failed:' + (err.message || err.toString()));
          });
      });
    });
  });
};
