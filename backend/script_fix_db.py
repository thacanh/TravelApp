from sqlalchemy import create_engine, text
from sqlalchemy.orm import sessionmaker
import json

engine = create_engine('mysql+pymysql://root:220104@localhost:3306/trawime_db')
Session = sessionmaker(bind=engine)
session = Session()

OLD_HTTP_8003 = 'http://192.168.100.222:8003'
OLD_HTTP_8000 = 'http://192.168.100.222:8000'
NEW_HTTPS = 'https://unpredaceously-suburbicarian-nelle.ngrok-free.dev'

print("Fixing Locations...")
locations = session.execute(text("SELECT id, thumbnail, images FROM locations")).fetchall()
for loc in locations:
    loc_id, thumb, imgs = loc
    new_thumb = thumb.replace(OLD_HTTP_8003, NEW_HTTPS).replace(OLD_HTTP_8000, NEW_HTTPS) if thumb else None
    
    new_imgs = None
    if imgs:
        if isinstance(imgs, str):
            imgs_list = json.loads(imgs)
        else:
            imgs_list = imgs
        
        updated_imgs = [i.replace(OLD_HTTP_8003, NEW_HTTPS).replace(OLD_HTTP_8000, NEW_HTTPS) for i in imgs_list]
        new_imgs = json.dumps(updated_imgs)
        
    session.execute(text("UPDATE locations SET thumbnail = :thumb, images = :imgs WHERE id = :id"), 
                    {"thumb": new_thumb, "imgs": new_imgs, "id": loc_id})

print("Fixing Users...")
users = session.execute(text("SELECT id, avatar_url FROM users")).fetchall()
for u in users:
    uid, avatar = u
    if avatar:
        new_avatar = avatar.replace(OLD_HTTP_8003, NEW_HTTPS).replace(OLD_HTTP_8000, NEW_HTTPS)
        session.execute(text("UPDATE users SET avatar_url = :av WHERE id = :id"), {"av": new_avatar, "id": uid})

print("Fixing Reviews...")
reviews = session.execute(text("SELECT id, photos FROM reviews")).fetchall()
for r in reviews:
    rid, photos = r
    if photos:
        if isinstance(photos, str):
            p_list = json.loads(photos)
        else:
            p_list = photos
            
        up_p = [p.replace(OLD_HTTP_8000, NEW_HTTPS).replace(OLD_HTTP_8003, NEW_HTTPS) for p in p_list]
        session.execute(text("UPDATE reviews SET photos = :p WHERE id = :id"), {"p": json.dumps(up_p), "id": rid})

session.commit()
print("URLs replaced successfully!")
