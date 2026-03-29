import os
import shutil
from typing import List
from fastapi import UploadFile, HTTPException
from uuid import uuid4
from ..config import settings

ALLOWED_EXTENSIONS = {"png", "jpg", "jpeg", "gif", "webp"}


def allowed_file(filename: str) -> bool:
    """Check if file extension is allowed"""
    return '.' in filename and filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS


def get_file_extension(filename: str) -> str:
    """Get file extension"""
    return filename.rsplit('.', 1)[1].lower() if '.' in filename else ""


async def save_upload_file(upload_file: UploadFile, subfolder: str = "") -> str:
    """
    Save uploaded file to disk and return the file path
    
    Args:
        upload_file: The uploaded file
        subfolder: Subfolder within upload directory (e.g., 'avatars', 'locations')
    
    Returns:
        Relative file path from upload directory
    """
    if not allowed_file(upload_file.filename):
        raise HTTPException(status_code=400, detail="File type not allowed")
    
    # Create upload directory if it doesn't exist
    upload_dir = os.path.join(settings.UPLOAD_DIR, subfolder)
    os.makedirs(upload_dir, exist_ok=True)
    
    # Generate unique filename
    file_extension = get_file_extension(upload_file.filename)
    unique_filename = f"{uuid4()}.{file_extension}"
    file_path = os.path.join(upload_dir, unique_filename)
    
    # Save file
    with open(file_path, "wb") as buffer:
        shutil.copyfileobj(upload_file.file, buffer)
    
    # Return relative path
    return os.path.join(subfolder, unique_filename).replace("\\", "/")


async def save_multiple_files(upload_files: List[UploadFile], subfolder: str = "") -> List[str]:
    """Save multiple uploaded files"""
    file_paths = []
    for upload_file in upload_files:
        file_path = await save_upload_file(upload_file, subfolder)
        file_paths.append(file_path)
    return file_paths


def delete_file(file_path: str) -> bool:
    """Delete a file from disk"""
    try:
        full_path = os.path.join(settings.UPLOAD_DIR, file_path)
        if os.path.exists(full_path):
            os.remove(full_path)
            return True
    except Exception:
        pass
    return False
