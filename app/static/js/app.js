/* ============================================================
   CloudTodo - Frontend Interactions & Dynamic Behavior
   ============================================================ */

document.addEventListener("DOMContentLoaded", () => {
    initCharCounter();
    initFilterTabs();
    initAutoDismissFlashes();
    initFormSubmissions();
});

/**
 * Update the character counter as the user types in the task input.
 */
function initCharCounter() {
    const taskInput = document.getElementById("task_name");
    const charCounter = document.getElementById("char-counter");

    if (taskInput && charCounter) {
        const updateCounter = () => {
            const length = taskInput.value.length;
            charCounter.textContent = `${length} / 250`;
            if (length >= 240) {
                charCounter.style.color = "var(--accent-warning)";
            } else {
                charCounter.style.color = "var(--text-muted)";
            }
        };

        taskInput.addEventListener("input", updateCounter);
        // Initial call in case form is prefilled (e.g. edit page)
        updateCounter();
    }
}

/**
 * Filter task rows dynamically without page reload.
 */
function initFilterTabs() {
    const tabButtons = document.querySelectorAll(".tab-btn");
    const taskRows = document.querySelectorAll(".task-row");

    if (!tabButtons.length || !taskRows.length) return;

    tabButtons.forEach(btn => {
        btn.addEventListener("click", () => {
            tabButtons.forEach(b => b.classList.remove("active"));
            btn.classList.add("active");

            const filter = btn.getAttribute("data-filter");

            taskRows.forEach(row => {
                const status = row.getAttribute("data-status");
                if (filter === "all" || status === filter) {
                    row.style.display = "";
                } else {
                    row.style.display = "none";
                }
            });
        });
    });
}

/**
 * Auto-dismiss flash alerts after 6 seconds with smooth fade out.
 */
function initAutoDismissFlashes() {
    const alerts = document.querySelectorAll(".flash-alert");
    alerts.forEach(alert => {
        setTimeout(() => {
            alert.style.transition = "opacity 0.4s ease, transform 0.4s ease";
            alert.style.opacity = "0";
            alert.style.transform = "translateY(-10px)";
            setTimeout(() => {
                alert.remove();
            }, 400);
        }, 6000);
    });
}

/**
 * Prevent duplicate form submission and show loading feedback on primary actions.
 */
function initFormSubmissions() {
    const forms = document.querySelectorAll("form");
    forms.forEach(form => {
        form.addEventListener("submit", (e) => {
            const submitBtn = form.querySelector('button[type="submit"]');
            if (submitBtn && !form.classList.contains("toggle-form") && !form.classList.contains("inline-form")) {
                submitBtn.style.opacity = "0.75";
                submitBtn.style.pointerEvents = "none";
            }
        });
    });
}
