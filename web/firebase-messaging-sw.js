importScripts(
  'https://www.gstatic.com/firebasejs/10.14.1/firebase-app-compat.js',
);
importScripts(
  'https://www.gstatic.com/firebasejs/10.14.1/firebase-messaging-compat.js',
);

firebase.initializeApp({
  apiKey: 'AIzaSyBP1_2lK8yKKHlF-U_TC2AJA-Vc4W3XTKg',
  appId: '1:516426305461:web:48c42e7d394d2ee1e813fc',
  messagingSenderId: '516426305461',
  projectId: 'circum-2797c',
  authDomain: 'circum-2797c.firebaseapp.com',
  storageBucket: 'circum-2797c.appspot.com',
});

firebase.messaging();
