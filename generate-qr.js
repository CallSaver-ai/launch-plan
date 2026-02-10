const QRCode = require('qrcode');
const fs = require('fs');

const url = 'https://staging.api.callsaver.ai/q/bcard';

// Generate PNG file
QRCode.toFile('qr-bcard-staging.png', url, {
  width: 400,
  margin: 2,
  color: {
    dark: '#000000',
    light: '#FFFFFF',
  },
}, (err) => {
  if (err) throw err;
  console.log('Generated: qr-bcard-staging.png');
  console.log('URL encoded:', url);
});
