I will use "ExampleMailbox@domain.com" as my example here.

* **Check current permissions:**
  `get-mailboxpermission -identity "ExampleMailbox@domain.com"`
  
  ![image](https://github.com/user-attachments/assets/48d23153-b598-4060-8d1b-2d7910bf9fb7)


* **Add Editor rights:**
  `Add-MailboxFolderPermission -Identity "ExampleMailbox@domain.com:\Calendar" -User "FirstL@domain.com" -AccessRights Editor`
  
  ![image](https://github.com/user-attachments/assets/ddfb0b1c-e166-42eb-8ae3-0bc8b7d4de6e)



* **Verify Editor rights:**
  `Get-MailboxFolderPermission -Identity "ExampleMailbox@domain.com:\Calendar"`
  ![image](https://github.com/user-attachments/assets/e12cf394-8613-471d-b6b0-118db36ed8a1)

  

---

When you assign someone as a Delegate to a Shared Mailbox in the Exchange Admin Center (admin web portal) it grants them "Full Access" rights -- but this is different from "Editor" rights. They need to be an Editor to be able to delete items from the mailbox. This permission level should be restricted to a small group of people generally speaking.
