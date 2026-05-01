{
  "uuid": "snap_2023_acc0001",            // 📌 μοναδικό ID του snapshot
  "account_id": "acc_0001",               // ID του λογαριασμού
  "user_id": "user_001",                  // ID χρήστη
  "year": 2023,                           // για γρήγορα queries
  "currency": "EUR",                      // νομισματική μονάδα
  "closing_balance": 385.50,              // το υπόλοιπο στο τέλος του έτους
  "total_income": 1200.00,                // σύνολο εσόδων
  "total_expense": 914.50,                // σύνολο εξόδων
  "generated_at": "2024-01-01T00:00:00Z", // πότε δημιουργήθηκε το snapshot (business timestamp)
  "created_at": "2024-01-01T00:00:01Z",   // Firestore timestamp για sync
  "updated_at": "2024-01-01T00:00:01Z",   // Firestore timestamp για sync
  "last_modified_device_id": "dev_001",   // για sync tracking
  "deleted": false                        // soft delete flag
}
