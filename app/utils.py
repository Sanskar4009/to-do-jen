from datetime import datetime, timezone
from typing import Optional, Tuple


def validate_task_name(name: Optional[str], min_length: int = 1, max_length: int = 250) -> Tuple[bool, Optional[str], str]:
    """Validate task name.

    Rules:
    - Must not be None or empty.
    - Strips whitespace.
    - Must have length >= min_length and <= max_length.

    Returns:
        (is_valid, error_message, cleaned_name)
    """
    if name is None:
        return False, "Task name is required.", ""

    cleaned = name.strip()

    if not cleaned:
        return False, "Task name cannot be empty or just whitespace.", ""

    if len(cleaned) < min_length:
        return False, f"Task name must be at least {min_length} character(s) long.", cleaned

    if len(cleaned) > max_length:
        return False, f"Task name cannot exceed {max_length} characters.", cleaned

    return True, None, cleaned


def format_iso_timestamp(iso_str: Optional[str]) -> str:
    """Format an ISO 8601 UTC timestamp string into a human-readable format.

    Example: '2026-10-02T12:30:00+00:00' -> 'Oct 02, 2026, 12:30 UTC'
    """
    if not iso_str:
        return "N/A"

    try:
        # Handle trailing Z or timezone offsets
        dt_str = iso_str.replace("Z", "+00:00")
        dt = datetime.fromisoformat(dt_str)
        return dt.strftime("%b %d, %Y • %H:%M UTC")
    except Exception:
        return str(iso_str)
