import logging
from flask import Blueprint, flash, redirect, render_template, request, url_for
from botocore.exceptions import ClientError

from app import dynamodb, sns_service
from app.utils import validate_task_name

logger = logging.getLogger(__name__)

bp = Blueprint("main", __name__)


@bp.route("/", methods=["GET"])
def index():
    """Display task dashboard with all tasks and metrics."""
    try:
        tasks = dynamodb.get_tasks()
    except (ClientError, Exception) as e:
        logger.error("Failed to load tasks from DynamoDB: %s", str(e))
        flash("Unable to fetch tasks from the database. Please verify AWS connectivity.", "danger")
        tasks = []

    total_tasks = len(tasks)
    completed_tasks = sum(1 for t in tasks if t.get("completed"))
    pending_tasks = total_tasks - completed_tasks

    return render_template(
        "index.html",
        tasks=tasks,
        total_tasks=total_tasks,
        completed_tasks=completed_tasks,
        pending_tasks=pending_tasks,
    )


@bp.route("/add", methods=["POST"])
def add_task():
    """Create a new task."""
    raw_name = request.form.get("task_name")
    is_valid, error_msg, cleaned_name = validate_task_name(raw_name)

    if not is_valid:
        flash(error_msg, "warning")
        return redirect(url_for("main.index"))

    try:
        created_task = dynamodb.create_task(cleaned_name)
        if created_task:
            flash(f'Task "{cleaned_name}" created successfully!', "success")
            # Trigger SNS notification (fails gracefully if SNS unavailable)
            sns_service.notify_task_created(
                task_name=created_task["task_name"],
                created_at=created_task["created_at"],
            )
        else:
            flash("Could not create task. Please try again.", "danger")
    except (ClientError, Exception) as e:
        logger.error("Error creating task in DynamoDB: %s", str(e))
        flash("Database error: Could not create task.", "danger")

    return redirect(url_for("main.index"))


@bp.route("/complete/<task_id>", methods=["POST"])
def toggle_task(task_id: str):
    """Toggle completed status of a task."""
    if not task_id:
        flash("Invalid task identifier provided.", "warning")
        return redirect(url_for("main.index"))

    try:
        updated_task = dynamodb.toggle_task(task_id)
        if not updated_task:
            flash("Task not found or could not be updated.", "warning")
            return redirect(url_for("main.index"))

        is_completed = bool(updated_task.get("completed", False))
        task_name = updated_task.get("task_name", "Task")

        if is_completed:
            flash(f'"{task_name}" marked as completed!', "success")
            sns_service.notify_task_completed(task_name)
        else:
            flash(f'"{task_name}" moved back to pending.', "info")
            sns_service.notify_task_reopened(task_name)

    except (ClientError, Exception) as e:
        logger.error("Error toggling task %s: %s", task_id, str(e))
        flash("Database error: Could not toggle task status.", "danger")

    return redirect(url_for("main.index"))


@bp.route("/edit/<task_id>", methods=["GET", "POST"])
def edit_task(task_id: str):
    """View edit form (GET) or update task details (POST)."""
    if not task_id:
        flash("Invalid task identifier.", "warning")
        return redirect(url_for("main.index"))

    if request.method == "GET":
        try:
            task = dynamodb.get_task(task_id)
            if not task:
                flash("Task not found.", "warning")
                return redirect(url_for("main.index"))
            return render_template("edit.html", task=task)
        except (ClientError, Exception) as e:
            logger.error("Error retrieving task for edit %s: %s", task_id, str(e))
            flash("Database error: Could not retrieve task details.", "danger")
            return redirect(url_for("main.index"))

    # POST request: Update task
    raw_name = request.form.get("task_name")
    is_valid, error_msg, cleaned_name = validate_task_name(raw_name)

    if not is_valid:
        flash(error_msg, "warning")
        return redirect(url_for("main.edit_task", task_id=task_id))

    try:
        updated_task = dynamodb.update_task(task_id, cleaned_name)
        if not updated_task:
            flash("Task not found or failed to update.", "warning")
            return redirect(url_for("main.index"))

        status = "Completed" if updated_task.get("completed") else "Pending"
        flash("Task updated successfully!", "success")
        sns_service.notify_task_updated(cleaned_name, status)
    except (ClientError, Exception) as e:
        logger.error("Error updating task %s: %s", task_id, str(e))
        flash("Database error: Failed to update task.", "danger")

    return redirect(url_for("main.index"))


@bp.route("/delete/<task_id>", methods=["POST"])
def delete_task(task_id: str):
    """Delete a task."""
    if not task_id:
        flash("Invalid task identifier.", "warning")
        return redirect(url_for("main.index"))

    try:
        # Retrieve name before deleting for SNS notification
        existing_task = dynamodb.get_task(task_id)
        task_name = existing_task.get("task_name", "Task") if existing_task else "Task"

        success = dynamodb.delete_task(task_id)
        if success:
            flash(f'Task "{task_name}" deleted successfully.', "success")
            sns_service.notify_task_deleted(task_name)
        else:
            flash("Task was already deleted or not found.", "warning")
    except (ClientError, Exception) as e:
        logger.error("Error deleting task %s: %s", task_id, str(e))
        flash("Database error: Could not delete task.", "danger")

    return redirect(url_for("main.index"))
