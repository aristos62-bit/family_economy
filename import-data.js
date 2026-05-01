const admin = require("firebase-admin");
const fs = require("fs");
const path = require("path");

// 🔐 Replace with your service account file
const serviceAccount = require("./serviceAccountKey.json");

// 🔥 Init Firebase Admin
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

// 📁 Folder with JSON files
const dataFolder = path.join(__dirname, "data");

// 🛠 Helper: Load and insert JSON file into Firestore
async function importCollection(fileName, collectionName) {
  const filePath = path.join(dataFolder, fileName);
  if (!fs.existsSync(filePath)) {
    console.log(`❌ File not found: ${filePath}`);
    return;
  }

  const jsonData = JSON.parse(fs.readFileSync(filePath, "utf8"));
  console.log(`⏳ Importing ${jsonData.length} documents to "${collectionName}"...`);

  for (const doc of jsonData) {
    const docId = doc.uuid || doc.id || undefined;
    const docRef = docId
      ? db.collection(collectionName).doc(docId)
      : db.collection(collectionName).doc(); // auto-ID if no uuid

    await docRef.set(doc);
  }

  console.log(`✅ Imported ${collectionName} successfully.\n`);
}

// 🏁 Main Import Process
async function runImport() {
  const files = fs.readdirSync(dataFolder).filter(f => f.endsWith(".json"));

  for (const file of files) {
    const collectionName = path.basename(file, ".json");
    await importCollection(file, collectionName);
  }

  console.log("🎉 All collections imported!");
}

runImport().catch(console.error);
