import os
import secrets
from typing import Optional

from fastapi import Depends, FastAPI, HTTPException, status
from fastapi.security import HTTPBasic, HTTPBasicCredentials
from pydantic import BaseModel, Field

app = FastAPI(
    title="SpineCare optional landmark analysis",
    version="1.0.0",
    docs_url=None,
    redoc_url=None,
)
security = HTTPBasic(auto_error=True)


class Landmark(BaseModel):
    x: float
    y: float
    z: float
    visibility: Optional[float] = Field(default=None, ge=0, le=1)
    presence: Optional[float] = Field(default=None, ge=0, le=1)


class AnalysisRequest(BaseModel):
    landmarks: list[Landmark] = Field(min_length=1, max_length=100)
    client: str = Field(default="spinecare-mobile", max_length=64)
    schemaVersion: int = Field(default=1, ge=1)


def authenticate(credentials: HTTPBasicCredentials = Depends(security)) -> str:
    expected_user = os.environ.get("SPINECARE_SERVER_USER", "")
    expected_password = os.environ.get("SPINECARE_SERVER_PASSWORD", "")
    valid_user = secrets.compare_digest(credentials.username, expected_user)
    valid_password = secrets.compare_digest(credentials.password, expected_password)
    if not expected_user or not expected_password or not (valid_user and valid_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authentication required",
            headers={"WWW-Authenticate": "Basic"},
        )
    return credentials.username


@app.get("/health")
def health(_: str = Depends(authenticate)):
    return {"status": "ok", "service": "spinecare-landmark-analysis", "schemaVersion": 1}


@app.post("/analyze/pose")
def analyze_pose(request: AnalysisRequest, _: str = Depends(authenticate)):
    # Technical quality summary only; this endpoint intentionally makes no
    # medical, rehabilitation, posture-correction, or diagnosis claims.
    count = len(request.landmarks)
    confidence_values = [
        point.visibility
        for point in request.landmarks
        if point.visibility is not None
    ]
    low_confidence = sum(value < 0.5 for value in confidence_values)
    mean_confidence = (
        round(sum(confidence_values) / len(confidence_values), 3)
        if confidence_values
        else None
    )
    if not confidence_values:
        summary = f"Received {count} pose landmarks. Visibility confidence was not supplied."
    elif mean_confidence is not None and mean_confidence < 0.5:
        summary = "Pose visibility is limited. Improve lighting and camera framing, then retry."
    elif low_confidence:
        summary = f"Received {count} landmarks; {low_confidence} have low visibility confidence. Check framing."
    else:
        summary = f"Received {count} landmarks with generally visible keypoints. This is not a clinical assessment."
    return {
        "summary": summary,
        "landmarkCount": count,
        "meanVisibility": mean_confidence,
        "lowVisibilityCount": low_confidence,
        "clinicalAssessment": False,
    }
