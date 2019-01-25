

{% mermaid %}
graph TD;
    google_compute_address-->google_compute_forwarding_rule;
    google_compute_forwarding_rule-->google_compute_region_backend_service;
    google_compute_region_backend_service-->google_compute_instange_group_manager;
    google_compute_region_backend_service-->google_compute_health_check;
    google_compute_instange_group_manager-->google_compute_health_check;
    google_compute_instange_template-->google_compute_instange_group_manager;
    style google_compute_instange_template fill:#ccf,stroke:#f66,stroke-width:2px,stroke-dasharray: 5, 5
{% endmermaid %}

