from pydantic import BaseModel
from typing import Optional


class CategoryBase(BaseModel):
    slug: str
    name: str
    icon: Optional[str] = None


class CategoryCreate(CategoryBase):
    pass


class CategoryResponse(CategoryBase):
    id: int

    class Config:
        from_attributes = True
