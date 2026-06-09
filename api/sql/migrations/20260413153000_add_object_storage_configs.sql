CREATE TABLE public.object_storage_configs (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    provider character varying(50) DEFAULT 'backblaze_b2'::character varying NOT NULL,
    endpoint text,
    region character varying(50) NOT NULL,
    encrypted_key_id text,
    encrypted_application_key text,
    private_bucket character varying(100) NOT NULL,
    public_bucket character varying(100),
    public_base_url text,
    upload_url_ttl_seconds integer NOT NULL,
    download_url_ttl_seconds integer NOT NULL,
    version integer NOT NULL,
    status character varying(50) DEFAULT 'active'::character varying NOT NULL,
    rollback_source_version integer,
    change_note text,
    created_by character varying(100),
    applied_by character varying(100),
    activated_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT object_storage_configs_pkey PRIMARY KEY (id),
    CONSTRAINT object_storage_configs_version_key UNIQUE (version)
);

CREATE UNIQUE INDEX idx_object_storage_configs_active_unique
    ON public.object_storage_configs (status)
    WHERE (status = 'active');

CREATE INDEX idx_object_storage_configs_provider
    ON public.object_storage_configs (provider);

CREATE INDEX idx_object_storage_configs_status
    ON public.object_storage_configs (status);

CREATE INDEX idx_object_storage_configs_rollback_source_version
    ON public.object_storage_configs (rollback_source_version);
