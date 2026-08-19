import os
import uvicorn
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import List, Optional, Dict, Any
from dotenv import load_dotenv
from database import init_db, get_db

load_dotenv()
SECRET_KEY = os.getenv("SECRET_KEY", "36a8b28c9e0246ed6b1058f9c4998b97")

from contextlib import asynccontextmanager

@asynccontextmanager
async def lifespan(app: FastAPI):
    init_db()
    yield

app = FastAPI(
    title="Maktab Manager Self-Hosted REST API",
    version="2.0.0",
    description="100% Free Production REST API for Maktab Quran School Management",
    lifespan=lifespan
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/health")
def health_check():
    db_type = "PostgreSQL Cloud Database" if os.getenv("DATABASE_URL") else "Local Persistent SQLite"
    return {
        "status": "ok",
        "service": "Maktab Manager REST API",
        "database": db_type,
        "environment": "Production Cloud / Self-Hosted"
    }

class AuthRequest(BaseModel):
    pin_hash: str

class SyncPushRequest(BaseModel):
    maktab_id: str
    users: Optional[List[Dict[str, Any]]] = []
    batches: Optional[List[Dict[str, Any]]] = []
    students: Optional[List[Dict[str, Any]]] = []
    attendance: Optional[List[Dict[str, Any]]] = []
    teacher_attendance: Optional[List[Dict[str, Any]]] = []
    quran_progress: Optional[List[Dict[str, Any]]] = []
    fee_payments: Optional[List[Dict[str, Any]]] = []

@app.post("/api/v1/auth/login")
def login(req: AuthRequest):
    conn = get_db()
    cursor = conn.cursor()
    cursor.execute("SELECT * FROM users WHERE pin_hash = ? AND is_active = 1", (req.pin_hash,))
    user = cursor.fetchone()
    conn.close()
    if not user:
        raise HTTPException(status_code=401, detail="Invalid PIN credentials")
    return {
        "success": True,
        "user": user,
        "maktab_id": user["maktab_id"]
    }

@app.get("/api/v1/sync/pull/{maktab_id}")
def pull_sync(maktab_id: str):
    conn = get_db()
    cursor = conn.cursor()

    cursor.execute("SELECT * FROM users WHERE maktab_id = ?", (maktab_id,))
    users = cursor.fetchall()

    cursor.execute("SELECT * FROM batches WHERE maktab_id = ?", (maktab_id,))
    batches = cursor.fetchall()

    cursor.execute("SELECT * FROM students WHERE maktab_id = ?", (maktab_id,))
    students = cursor.fetchall()

    cursor.execute("SELECT * FROM attendance WHERE maktab_id = ?", (maktab_id,))
    attendance = cursor.fetchall()

    cursor.execute("SELECT * FROM teacher_attendance WHERE maktab_id = ?", (maktab_id,))
    teacher_attendance = cursor.fetchall()

    cursor.execute("SELECT * FROM quran_progress WHERE maktab_id = ?", (maktab_id,))
    quran_progress = cursor.fetchall()

    cursor.execute("SELECT * FROM fee_payments WHERE maktab_id = ?", (maktab_id,))
    fee_payments = cursor.fetchall()

    conn.close()

    return {
        "maktab_id": maktab_id,
        "users": users,
        "batches": batches,
        "students": students,
        "attendance": attendance,
        "teacher_attendance": teacher_attendance,
        "quran_progress": quran_progress,
        "fee_payments": fee_payments
    }

@app.post("/api/v1/sync/push")
def push_sync(req: SyncPushRequest):
    maktab_id = req.maktab_id
    conn = get_db()
    cursor = conn.cursor()

    # 1. Users
    for u in req.users or []:
        cursor.execute("""
        INSERT INTO users (id, maktab_id, name, pin_hash, role, mobile, created_at, is_active, photo_path)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(id) DO UPDATE SET
            maktab_id=excluded.maktab_id,
            name=excluded.name,
            pin_hash=excluded.pin_hash,
            role=excluded.role,
            mobile=excluded.mobile,
            created_at=excluded.created_at,
            is_active=excluded.is_active,
            photo_path=excluded.photo_path
        """, (
            u.get("id"), maktab_id, u.get("name"), u.get("pin_hash") or u.get("pinHash"),
            u.get("role"), u.get("mobile"), u.get("created_at") or u.get("createdAt"),
            1 if u.get("is_active", True) else 0, u.get("photo_path") or u.get("photoPath")
        ))

    # 2. Batches
    for b in req.batches or []:
        cursor.execute("""
        INSERT INTO batches (id, maktab_id, name, section, room, teacher_id, created_at)
        VALUES (?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(id) DO UPDATE SET
            maktab_id=excluded.maktab_id,
            name=excluded.name,
            section=excluded.section,
            room=excluded.room,
            teacher_id=excluded.teacher_id,
            created_at=excluded.created_at
        """, (
            b.get("id"), maktab_id, b.get("name"), b.get("section"),
            b.get("room"), b.get("teacher_id") or b.get("teacherId"),
            b.get("created_at") or b.get("createdAt")
        ))

    # 3. Students
    for s in req.students or []:
        cursor.execute("""
        INSERT INTO students (id, maktab_id, name, guardian_name, guardian_phone, batch_id, dob, gender, address, admission_date, roll_number, photo_path, teacher_note, is_deleted, deleted_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(id) DO UPDATE SET
            maktab_id=excluded.maktab_id,
            name=excluded.name,
            guardian_name=excluded.guardian_name,
            guardian_phone=excluded.guardian_phone,
            batch_id=excluded.batch_id,
            dob=excluded.dob,
            gender=excluded.gender,
            address=excluded.address,
            admission_date=excluded.admission_date,
            roll_number=excluded.roll_number,
            photo_path=excluded.photo_path,
            teacher_note=excluded.teacher_note,
            is_deleted=excluded.is_deleted,
            deleted_at=excluded.deleted_at
        """, (
            s.get("id"), maktab_id, s.get("name"), s.get("guardian_name") or s.get("guardianName"),
            s.get("guardian_phone") or s.get("guardianPhone"), s.get("batch_id") or s.get("batchId"),
            s.get("dob"), s.get("gender"), s.get("address"), s.get("admission_date") or s.get("admissionDate"),
            s.get("roll_number") or s.get("rollNumber"), s.get("photo_path") or s.get("photoPath"),
            s.get("teacher_note") or s.get("teacherNote"),
            1 if (s.get("is_deleted") or s.get("isDeleted")) else 0,
            s.get("deleted_at") or s.get("deletedAt")
        ))

    # 4. Attendance
    for a in req.attendance or []:
        cursor.execute("""
        INSERT INTO attendance (id, maktab_id, student_id, date, status, remarks, time)
        VALUES (?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(id) DO UPDATE SET
            maktab_id=excluded.maktab_id,
            student_id=excluded.student_id,
            date=excluded.date,
            status=excluded.status,
            remarks=excluded.remarks,
            time=excluded.time
        """, (
            a.get("id"), maktab_id, a.get("student_id") or a.get("studentId"),
            a.get("date"), a.get("status"), a.get("remarks"), a.get("time")
        ))

    # 5. Teacher Attendance
    for ta in req.teacher_attendance or []:
        cursor.execute("""
        INSERT INTO teacher_attendance (id, maktab_id, teacher_id, date, status, check_in_time, check_out_time, remarks)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(id) DO UPDATE SET
            maktab_id=excluded.maktab_id,
            teacher_id=excluded.teacher_id,
            date=excluded.date,
            status=excluded.status,
            check_in_time=excluded.check_in_time,
            check_out_time=excluded.check_out_time,
            remarks=excluded.remarks
        """, (
            ta.get("id"), maktab_id, ta.get("teacher_id") or ta.get("teacherId"),
            ta.get("date"), ta.get("status"),
            ta.get("check_in_time") or ta.get("checkInTime"),
            ta.get("check_out_time") or ta.get("checkOutTime"),
            ta.get("remarks")
        ))

    # 6. Quran Progress
    for qp in req.quran_progress or []:
        cursor.execute("""
        INSERT INTO quran_progress (id, maktab_id, student_id, date, surah, ayah_from, ayah_to, grade, remarks)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(id) DO UPDATE SET
            maktab_id=excluded.maktab_id,
            student_id=excluded.student_id,
            date=excluded.date,
            surah=excluded.surah,
            ayah_from=excluded.ayah_from,
            ayah_to=excluded.ayah_to,
            grade=excluded.grade,
            remarks=excluded.remarks
        """, (
            qp.get("id"), maktab_id, qp.get("student_id") or qp.get("studentId"),
            qp.get("date"), qp.get("surah"),
            qp.get("ayah_from") or qp.get("ayahFrom"),
            qp.get("ayah_to") or qp.get("ayahTo"),
            qp.get("grade"), qp.get("remarks")
        ))

    # 7. Fee Payments
    for f in req.fee_payments or []:
        cursor.execute("""
        INSERT INTO fee_payments (id, maktab_id, student_id, amount, payment_date, month, year, payment_method, receipt_number, remarks, timestamp)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(id) DO UPDATE SET
            maktab_id=excluded.maktab_id,
            student_id=excluded.student_id,
            amount=excluded.amount,
            payment_date=excluded.payment_date,
            month=excluded.month,
            year=excluded.year,
            payment_method=excluded.payment_method,
            receipt_number=excluded.receipt_number,
            remarks=excluded.remarks,
            timestamp=excluded.timestamp
        """, (
            f.get("id"), maktab_id, f.get("student_id") or f.get("studentId"),
            f.get("amount"), f.get("payment_date") or f.get("paymentDate"),
            f.get("month"), f.get("year"),
            f.get("payment_method") or f.get("paymentMethod"),
            f.get("receipt_number") or f.get("receiptNumber"),
            f.get("remarks"), f.get("timestamp")
        ))

    conn.commit()
    conn.close()

    return {"status": "success", "message": "Synced successfully"}

if __name__ == "__main__":
    port = int(os.getenv("PORT", 8000))
    uvicorn.run("main:app", host="0.0.0.0", port=port, reload=False)
