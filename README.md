# LiteDB

LiteDb is a thin IOS `Swift` wrapper around `SQLITE3` database.


## Usage

```swift
import LiteDB

//Define your Table
class Contacts: Table {
    
    let id     = Column(name: "c_uid", primary_key: true, auto_increment: true)
    let name   = Column(name: "c_name")
    let period = Column(name: "c_period", type: .DATETIME/*, default_value: "CURRENT_TIMESTAMP"*/)
    let total  = Column(name: "c_total", type: .DECIMAL/*, default_value: 78.5632*/)
    
    override var tablename: String { return "c_contacts" }
}

//Create you sqlite3 database 
let db = Database.sharedInstance("mydatabase.sqlite3")

//Test whether its opened
if db.isOpen() {
    do {
        let c = Contacts(db: db)
        c["name"] = "John Doe"
        c["period"] = DateTime()
        c["total"] = 120.78
        
        let lastrowinserted = try c.insert()
        // c["id"] now contains lastrowinserted
        
        try db.close();
        try db.remove()
    }
    catch( let error ) {
        print(error)
    }
}
```

License
=======
Copyright 2022 Emmanuel Adigun. emmanuel@zignal.get

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
