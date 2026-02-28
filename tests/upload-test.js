require('dotenv').config();
const { createPresignedUploadUrl } = require('../vault');
const { execSync } = require('child_process');

(async () => {
    const { uploadUrl } = await createPresignedUploadUrl('seeron.jpg', 'image/jpeg');
    const cmd = `curl -X PUT "${uploadUrl}" -H "Content-Type: image/jpeg" --upload-file "C:\\Users\\seero\\Downloads\\seeron.jpg"`;
    console.log('Running upload...');
    const result = execSync(cmd).toString();
    console.log('Response:', result);
})();