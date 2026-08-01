-- RedCode IM 数据库当前基线（2026-06-09 整合重置：折叠历史增量迁移）
-- 说明：
-- 1. 本文件覆盖当前 schema、视图、函数与基础 seed 数据，可直接初始化空库。
-- 2. 运行态迁移记录表 db_migrations 不包含在本基线中。
-- 3. 后续数据库变更从 api/sql/migrations/ 追加增量脚本（additive-only，由 make migration.guard 强制）。
--
-- PostgreSQL database dump
--



SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', 'public', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;


--
-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';


--
-- Name: cleanup_old_user_logs(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.cleanup_old_user_logs() RETURNS integer
    LANGUAGE plpgsql
    AS $$
DECLARE
    deleted_count INTEGER;
BEGIN
    -- 删除1年前的用户登录历史
    DELETE FROM user_login_history
    WHERE login_at < NOW() - INTERVAL '1 year';

    GET DIAGNOSTICS deleted_count = ROW_COUNT;

    -- 删除3个月前的用户心跳记录
    DELETE FROM user_heartbeat_logs
    WHERE heartbeat_at < NOW() - INTERVAL '3 months';

    RETURN deleted_count;
END;
$$;


--
-- Name: FUNCTION cleanup_old_user_logs(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.cleanup_old_user_logs() IS '清理过期用户日志数据，保留最近1年的登录历史和3个月的心跳记录。建议设置为定时任务每月执行一次。';


--
-- Name: update_updated_at_column(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_updated_at_column() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: admin_login_history; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.admin_login_history (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    admin_user_id uuid NOT NULL,
    ip_address inet,
    user_agent text,
    login_at timestamp with time zone DEFAULT now() NOT NULL,
    logout_at timestamp with time zone,
    success boolean DEFAULT true NOT NULL,
    failure_reason text
);


--
-- Name: admin_operation_logs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.admin_operation_logs (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    admin_user_id uuid,
    operation character varying(100) NOT NULL,
    resource_type character varying(50),
    resource_id uuid,
    details jsonb,
    ip_address inet,
    user_agent text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: admin_user_roles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.admin_user_roles (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    admin_user_id uuid NOT NULL,
    role_id uuid NOT NULL,
    assigned_by uuid,
    assigned_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: admin_users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.admin_users (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    username character varying(50) NOT NULL,
    email character varying(100) NOT NULL,
    password_hash character varying(255) NOT NULL,
    nickname character varying(100),
    avatar_url text,
    status smallint DEFAULT 0 NOT NULL,
    last_login_at timestamp with time zone,
    login_attempts smallint DEFAULT 0 NOT NULL,
    locked_until timestamp with time zone,
    require_password_change boolean DEFAULT false NOT NULL,
    password_changed_at timestamp with time zone DEFAULT now() NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone
);


--
-- Name: app_documents; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.app_documents (
    key text NOT NULL,
    title text NOT NULL,
    content text NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_by uuid
);


--
-- Name: app_versions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.app_versions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    platform text NOT NULL,
    version text NOT NULL,
    build_number integer NOT NULL,
    channel text DEFAULT 'stable'::text NOT NULL,
    download_key text NOT NULL,
    download_url text,
    file_size bigint,
    checksum text,
    signature text,
    release_notes text,
    mandatory boolean DEFAULT false NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    released_at timestamp with time zone,
    created_by uuid,
    updated_by uuid,
    app_store_url text,
    CONSTRAINT app_versions_platform_check CHECK ((platform = ANY (ARRAY['windows'::text, 'macos'::text, 'ios'::text, 'android'::text, 'linux'::text])))
);


--
-- Name: COLUMN app_versions.platform; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.app_versions.platform IS '支持平台: windows(Windows桌面), macos(macOS桌面), ios(iOS移动端), android(Android移动端), linux(Linux桌面)';


--
-- Name: captcha_settings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.captcha_settings (
    key text NOT NULL,
    enabled boolean DEFAULT false NOT NULL,
    captcha_code text DEFAULT ''::text NOT NULL,
    description text DEFAULT ''::text NOT NULL,
    require_captcha_for_login boolean DEFAULT false NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_by uuid
);


--
-- Name: e2ee_identity_keys; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.e2ee_identity_keys (
    user_id uuid NOT NULL,
    device_id text NOT NULL,
    public_key bytea NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT e2ee_identity_keys_device_id_len CHECK (((char_length(device_id) > 0) AND (char_length(device_id) <= 128)))
);


--
-- Name: TABLE e2ee_identity_keys; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.e2ee_identity_keys IS 'E2EE 身份公钥表（按 user_id + device_id 维度）';


--
-- Name: e2ee_one_time_pre_keys; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.e2ee_one_time_pre_keys (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    device_id text NOT NULL,
    key_id integer NOT NULL,
    public_key bytea NOT NULL,
    is_used boolean DEFAULT false NOT NULL,
    used_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT e2ee_one_time_pre_keys_device_id_len CHECK (((char_length(device_id) > 0) AND (char_length(device_id) <= 128)))
);


--
-- Name: TABLE e2ee_one_time_pre_keys; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.e2ee_one_time_pre_keys IS 'E2EE 一次性预密钥表（按 user_id + device_id 维度，取用后标记 is_used）';


--
-- Name: e2ee_signed_pre_keys; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.e2ee_signed_pre_keys (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    device_id text NOT NULL,
    key_id integer NOT NULL,
    public_key bytea NOT NULL,
    signature bytea NOT NULL,
    expires_at timestamp with time zone NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT e2ee_signed_pre_keys_device_id_len CHECK (((char_length(device_id) > 0) AND (char_length(device_id) <= 128)))
);


--
-- Name: TABLE e2ee_signed_pre_keys; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.e2ee_signed_pre_keys IS 'E2EE 签名预密钥表（按 user_id + device_id 维度，支持轮换）';


--
-- Name: emoji_items; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.emoji_items (
    id uuid NOT NULL,
    pack_id uuid NOT NULL,
    image_url text NOT NULL,
    name character varying(100),
    sort_order integer DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    image_object_key text
);


--
-- Name: emoji_packs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.emoji_packs (
    id uuid NOT NULL,
    name character varying(100) NOT NULL,
    icon_url text,
    description text,
    pack_type smallint DEFAULT 0 NOT NULL,
    parent_id uuid,
    is_active smallint DEFAULT 1 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    icon_object_key text
);


--
-- Name: feedbacks; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.feedbacks (
    id uuid NOT NULL,
    user_id uuid NOT NULL,
    contact text,
    content text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: file_upload_audit_tasks; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.file_upload_audit_tasks (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    storage_provider_id uuid NOT NULL,
    object_key text NOT NULL,
    scene text NOT NULL,
    media_kind text NOT NULL,
    content_type text,
    file_size bigint,
    status smallint DEFAULT 0 NOT NULL,
    vendor_job_id text,
    result jsonb DEFAULT '{}'::jsonb NOT NULL,
    rejected_reason text,
    attempts integer DEFAULT 0 NOT NULL,
    next_run_at timestamp with time zone DEFAULT now() NOT NULL,
    last_error text,
    audited_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: file_upload_multipart_sessions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.file_upload_multipart_sessions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    storage_provider_id uuid NOT NULL,
    object_key text NOT NULL,
    upload_id text NOT NULL,
    creator_id uuid NOT NULL,
    creator_is_admin boolean DEFAULT false NOT NULL,
    file_size bigint,
    content_type text,
    part_size integer NOT NULL,
    total_parts integer NOT NULL,
    uploaded_parts jsonb DEFAULT '{}'::jsonb NOT NULL,
    status smallint DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    completed_at timestamp with time zone
);


--
-- Name: file_upload_records; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.file_upload_records (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    storage_provider_id uuid NOT NULL,
    object_key text NOT NULL,
    hash_alg smallint DEFAULT 1 NOT NULL,
    hash_value text NOT NULL,
    file_size bigint,
    content_type text,
    status smallint DEFAULT 0 NOT NULL,
    uploaded_at timestamp with time zone,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    last_error text
);


--
-- Name: friend_requests; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.friend_requests (
    id uuid NOT NULL,
    requester_id uuid NOT NULL,
    addressee_id uuid NOT NULL,
    status smallint DEFAULT 0 NOT NULL,
    message text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    responded_at timestamp with time zone,
    CONSTRAINT friend_requests_check CHECK ((requester_id <> addressee_id))
);


--
-- Name: friendships; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.friendships (
    id uuid NOT NULL,
    user_a_id uuid NOT NULL,
    user_b_id uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT friendships_check CHECK (((user_a_id <> user_b_id) AND ((user_a_id)::text < (user_b_id)::text)))
);


--
-- Name: general_settings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.general_settings (
    key text NOT NULL,
    value text DEFAULT ''::text NOT NULL,
    description text DEFAULT ''::text NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_by uuid
);


--
-- Name: group_admins; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.group_admins (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    room_id uuid NOT NULL,
    admin_id uuid NOT NULL,
    appointed_by uuid NOT NULL,
    role character varying(50) DEFAULT 'admin'::character varying NOT NULL,
    permissions text[],
    appointed_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: group_announcements; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.group_announcements (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    room_id uuid NOT NULL,
    title character varying(200) NOT NULL,
    content text NOT NULL,
    publisher_id uuid NOT NULL,
    is_pinned boolean DEFAULT false,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: group_settings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.group_settings (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    room_id uuid NOT NULL,
    join_approval_required boolean DEFAULT false NOT NULL,
    member_can_invite boolean DEFAULT true NOT NULL,
    member_can_add_friends boolean DEFAULT true NOT NULL,
    require_admin_to_add_friends boolean DEFAULT false NOT NULL,
    max_members integer DEFAULT 500 NOT NULL,
    global_mute_enabled boolean DEFAULT false NOT NULL,
    global_mute_until timestamp with time zone,
    global_mute_reason text,
    global_mute_set_by uuid,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: join_requests; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.join_requests (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    room_id uuid NOT NULL,
    applicant_id uuid NOT NULL,
    message text,
    status integer DEFAULT 0 NOT NULL,
    reviewer_id uuid,
    review_message text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    reviewed_at timestamp with time zone
);


--
-- Name: room_members; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.room_members (
    id uuid NOT NULL,
    room_id uuid NOT NULL,
    user_id uuid NOT NULL,
    role smallint DEFAULT 2 NOT NULL,
    joined_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    last_read_at timestamp with time zone,
    last_read_message_id uuid,
    notification_settings integer DEFAULT 0 NOT NULL
);


--
-- Name: COLUMN room_members.notification_settings; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.room_members.notification_settings IS '通知设置：0=全部通知，1=仅@通知，2=完全静音';


--
-- Name: rooms; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.rooms (
    id uuid NOT NULL,
    name character varying(100) NOT NULL,
    description text,
    avatar_url text,
    avatar_object_key text,
    room_type smallint DEFAULT 1 NOT NULL,
    owner_id uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone
);


--
-- Name: group_detail_view; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.group_detail_view AS
 SELECT r.id,
    r.name,
    r.description,
    r.avatar_url,
    r.avatar_object_key,
    r.room_type,
    r.owner_id,
    r.created_at,
    r.updated_at,
    COALESCE(gs.join_approval_required, false) AS join_approval_required,
    COALESCE(gs.member_can_invite, true) AS member_can_invite,
    COALESCE(gs.member_can_add_friends, true) AS member_can_add_friends,
    COALESCE(gs.require_admin_to_add_friends, false) AS require_admin_to_add_friends,
    COALESCE(gs.max_members, 500) AS max_members,
    COALESCE(gs.global_mute_enabled, false) AS global_mute_enabled,
    gs.global_mute_until,
    gs.global_mute_reason,
    gs.global_mute_set_by,
    ( SELECT count(*) AS count
           FROM public.room_members rm
          WHERE ((rm.room_id = r.id) AND (rm.deleted_at IS NULL))) AS current_member_count,
    ( SELECT count(*) AS count
           FROM public.join_requests jr
          WHERE ((jr.room_id = r.id) AND (jr.status = 0))) AS pending_request_count
   FROM (public.rooms r
     LEFT JOIN public.group_settings gs ON ((r.id = gs.room_id)))
  WHERE ((r.room_type = 1) AND (r.deleted_at IS NULL));


--
-- Name: group_invitations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.group_invitations (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    room_id uuid NOT NULL,
    inviter_id uuid NOT NULL,
    invitee_id uuid NOT NULL,
    message text,
    status integer DEFAULT 0 NOT NULL,
    invited_at timestamp with time zone DEFAULT now() NOT NULL,
    responded_at timestamp with time zone,
    expires_at timestamp with time zone DEFAULT (CURRENT_TIMESTAMP + '7 days'::interval) NOT NULL
);


--
-- Name: group_mutes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.group_mutes (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    room_id uuid NOT NULL,
    user_id uuid NOT NULL,
    muted_by uuid NOT NULL,
    reason text,
    mute_duration_hours integer DEFAULT 24,
    muted_at timestamp with time zone DEFAULT now() NOT NULL,
    unmuted_at timestamp with time zone,
    is_active boolean DEFAULT true
);


--
-- Name: group_operation_logs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.group_operation_logs (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    room_id uuid NOT NULL,
    operator_id uuid NOT NULL,
    target_user_id uuid,
    operation_type character varying(50) NOT NULL,
    operation_data jsonb,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: group_rules; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.group_rules (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    room_id uuid NOT NULL,
    title character varying(200) NOT NULL,
    content text NOT NULL,
    creator_id uuid NOT NULL,
    order_index integer DEFAULT 0 NOT NULL,
    is_active boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: hot_update_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.hot_update_events (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    platform text NOT NULL,
    channel text,
    base_version text NOT NULL,
    patch_version text NOT NULL,
    event_type text NOT NULL,
    client_id text,
    message text,
    client_type text,
    os_version text,
    os_arch text,
    app_arch text,
    build_number integer,
    trigger_source text,
    network_type text,
    device_info text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: COLUMN hot_update_events.client_type; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.hot_update_events.client_type IS '客户端类型：desktop（桌面端）或frontend（移动端）';


--
-- Name: COLUMN hot_update_events.os_version; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.hot_update_events.os_version IS '操作系统版本，如：Windows 11, iOS 17.1, Android 13';


--
-- Name: COLUMN hot_update_events.os_arch; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.hot_update_events.os_arch IS '操作系统架构：x64, arm64, arm等';


--
-- Name: COLUMN hot_update_events.app_arch; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.hot_update_events.app_arch IS '应用架构：x64, arm64, arm等';


--
-- Name: COLUMN hot_update_events.build_number; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.hot_update_events.build_number IS '构建号';


--
-- Name: COLUMN hot_update_events.trigger_source; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.hot_update_events.trigger_source IS '触发来源：manual（手动）、auto（自动）、notification（通知）';


--
-- Name: COLUMN hot_update_events.network_type; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.hot_update_events.network_type IS '网络类型：wifi, cellular, ethernet, unknown';


--
-- Name: COLUMN hot_update_events.device_info; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.hot_update_events.device_info IS '设备详细信息摘要，如：platform:Win32,lang:zh-CN,cookies:true';


--
-- Name: hot_updates; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.hot_updates (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    platform text NOT NULL,
    app_version_id uuid NOT NULL,
    patch_version text NOT NULL,
    channel text DEFAULT 'stable'::text NOT NULL,
    download_key text NOT NULL,
    download_url text,
    file_size bigint,
    checksum text,
    signature text,
    rollout_percentage integer DEFAULT 100 NOT NULL,
    mandatory boolean DEFAULT false NOT NULL,
    description text,
    is_active boolean DEFAULT true NOT NULL,
    released_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    created_by uuid,
    updated_by uuid,
    CONSTRAINT hot_updates_rollout_percentage_check CHECK (((rollout_percentage >= 0) AND (rollout_percentage <= 100)))
);


--
-- Name: ipinfo_tokens; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ipinfo_tokens (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name character varying(100) NOT NULL,
    token character varying(200) NOT NULL,
    monthly_limit integer DEFAULT 50000 NOT NULL,
    used_count integer DEFAULT 0 NOT NULL,
    reset_date date DEFAULT CURRENT_DATE NOT NULL,
    status character varying(20) DEFAULT 'active'::character varying NOT NULL,
    last_used_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT ipinfo_tokens_status_check CHECK (((status)::text = ANY (ARRAY[('active'::character varying)::text, ('exhausted'::character varying)::text])))
);


--
-- Name: message_parts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.message_parts (
    id uuid NOT NULL,
    message_id uuid NOT NULL,
    "position" smallint NOT NULL,
    part_type smallint NOT NULL,
    text_content text,
    attachment_key text,
    attachment_name text,
    attachment_mime text,
    attachment_size bigint,
    width integer,
    height integer,
    duration_ms integer,
    thumbnail_key text,
    extra jsonb,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: message_reactions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.message_reactions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    message_id uuid NOT NULL,
    user_id uuid NOT NULL,
    reaction_key text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone
);


--
-- Name: TABLE message_reactions; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.message_reactions IS '消息反应表，记录用户对消息的表情反应';


--
-- Name: COLUMN message_reactions.reaction_key; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.message_reactions.reaction_key IS '反应类型：👍 ❤️ 😂 🎉 😮 😢 等固定表情';


--
-- Name: COLUMN message_reactions.deleted_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.message_reactions.deleted_at IS '软删除时间，NULL 表示未删除';


--
-- Name: message_reads; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.message_reads (
    id uuid NOT NULL,
    message_id uuid NOT NULL,
    user_id uuid NOT NULL,
    room_id uuid NOT NULL,
    read_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: messages; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.messages (
    id uuid NOT NULL,
    room_id uuid NOT NULL,
    sender_id uuid NOT NULL,
    content text NOT NULL,
    message_type smallint DEFAULT 0 NOT NULL,
    quoted_message_id uuid,
    forward_from_message_id uuid,
    forward_from_room_id uuid,
    forward_from_sender_id uuid,
    forward_from_sender_username text,
    forward_from_sender_nickname text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone,
    edited_at timestamp with time zone,
    encrypted_content bytea,
    encryption_metadata jsonb
);


--
-- Name: COLUMN messages.edited_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.messages.edited_at IS '消息编辑时间，NULL 表示未编辑过';


--
-- Name: COLUMN messages.encrypted_content; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.messages.encrypted_content IS 'E2EE 密文载荷（服务端不解密，仅存储与透传）';


--
-- Name: COLUMN messages.encryption_metadata; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.messages.encryption_metadata IS 'E2EE 元数据（JSON），如算法/版本/iv/counter 等';


--
-- Name: object_storage_configs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.object_storage_configs (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    provider character varying(50) DEFAULT 's3_compatible'::character varying NOT NULL,
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
    updated_at timestamp with time zone DEFAULT CURRENT_TIMESTAMP NOT NULL
);


--
-- Name: permissions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.permissions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name character varying(100) NOT NULL,
    code character varying(50) NOT NULL,
    description text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: push_devices; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.push_devices (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    platform text NOT NULL,
    channel text NOT NULL,
    device_id text NOT NULL,
    device_token text NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    last_seen_at timestamp with time zone DEFAULT now() NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: TABLE push_devices; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.push_devices IS 'Push 设备表，记录用户设备 token（FCM/APNs）用于离线推送';


--
-- Name: COLUMN push_devices.device_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.push_devices.device_id IS '客户端生成的稳定设备 ID，用于 token 刷新/账号切换';


--
-- Name: COLUMN push_devices.device_token; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.push_devices.device_token IS '设备 token（FCM/APNs）';


--
-- Name: COLUMN push_devices.is_active; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.push_devices.is_active IS '是否启用：false 表示已注销/登出';


--
-- Name: push_job_queue; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.push_job_queue (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    job_type text NOT NULL,
    payload jsonb DEFAULT '{}'::jsonb NOT NULL,
    status smallint DEFAULT 0 NOT NULL,
    attempts integer DEFAULT 0 NOT NULL,
    next_run_at timestamp with time zone DEFAULT now() NOT NULL,
    last_error text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: TABLE push_job_queue; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.push_job_queue IS 'Push job 队列：用于 push job 落库与重试（内存队列溢出时使用）';


--
-- Name: COLUMN push_job_queue.job_type; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.push_job_queue.job_type IS '任务类型：message/friend_request/group_event';


--
-- Name: COLUMN push_job_queue.payload; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.push_job_queue.payload IS '任务 payload（JSON）';


--
-- Name: COLUMN push_job_queue.status; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.push_job_queue.status IS '任务状态：0=pending,1=done,2=failed,3=retry';


--
-- Name: COLUMN push_job_queue.attempts; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.push_job_queue.attempts IS '已尝试次数（用于退避与失败判定）';


--
-- Name: COLUMN push_job_queue.next_run_at; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.push_job_queue.next_run_at IS '下次可执行时间；也用作多节点租约';


--
-- Name: COLUMN push_job_queue.last_error; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.push_job_queue.last_error IS '最后一次错误信息';


--
-- Name: push_logs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.push_logs (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    push_id uuid NOT NULL,
    user_id uuid NOT NULL,
    device_id text NOT NULL,
    platform text NOT NULL,
    channel text NOT NULL,
    provider text NOT NULL,
    event_type text NOT NULL,
    room_id uuid,
    message_id uuid,
    request_id uuid,
    title text,
    body text,
    data jsonb DEFAULT '{}'::jsonb NOT NULL,
    attempt integer NOT NULL,
    success boolean NOT NULL,
    error text,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: TABLE push_logs; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.push_logs IS 'Push 发送日志：按设备记录 push 发送结果，用于追踪、排障与重试分析';


--
-- Name: COLUMN push_logs.push_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.push_logs.push_id IS '一次通知事件的追踪 ID，同一事件可能对多个设备产生多条日志';


--
-- Name: COLUMN push_logs.event_type; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.push_logs.event_type IS '通知事件类型：message/friend_request/group_event/...';


--
-- Name: push_provider_configs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.push_provider_configs (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    provider text NOT NULL,
    platform text DEFAULT 'all'::text NOT NULL,
    enabled boolean DEFAULT false NOT NULL,
    config_public jsonb DEFAULT '{}'::jsonb NOT NULL,
    secret_ciphertext text,
    secret_fingerprint text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_by uuid
);


--
-- Name: TABLE push_provider_configs; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.push_provider_configs IS 'Push 平台配置（FCM/APNs 等），由管理后台维护；敏感信息加密存储';


--
-- Name: COLUMN push_provider_configs.secret_ciphertext; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.push_provider_configs.secret_ciphertext IS '敏感配置（加密后的密文，base64 字符串）';


--
-- Name: COLUMN push_provider_configs.secret_fingerprint; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.push_provider_configs.secret_fingerprint IS '敏感配置指纹（sha256 hex，不可逆）';


--
-- Name: report_attachments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.report_attachments (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    report_id uuid NOT NULL,
    object_key text NOT NULL,
    content_type text,
    file_size bigint,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: reports; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.reports (
    id uuid NOT NULL,
    reporter_id uuid NOT NULL,
    target_type integer NOT NULL,
    target_room_id uuid,
    target_user_id uuid,
    content text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT reports_check CHECK ((((target_type = 1) AND (target_room_id IS NOT NULL) AND (target_user_id IS NULL)) OR ((target_type = 2) AND (target_user_id IS NOT NULL) AND (target_room_id IS NULL)))),
    CONSTRAINT reports_target_type_check CHECK ((target_type = ANY (ARRAY[1, 2])))
);


--
-- Name: role_permissions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.role_permissions (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    role_id uuid NOT NULL,
    permission_id uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: roles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.roles (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    name character varying(100) NOT NULL,
    code character varying(50) NOT NULL,
    description text,
    is_system boolean DEFAULT false,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: room_pins; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.room_pins (
    room_id uuid NOT NULL,
    message_id uuid NOT NULL,
    pinned_by uuid NOT NULL,
    pinned_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: storage_providers; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.storage_providers (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    provider_type smallint DEFAULT 1 NOT NULL,
    name character varying(100) NOT NULL,
    secret_id text NOT NULL,
    secret_key text NOT NULL,
    region character varying(50) NOT NULL,
    endpoint text NOT NULL,
    bucket_name character varying(100),
    is_active boolean DEFAULT false NOT NULL,
    is_default boolean DEFAULT false NOT NULL,
    description text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_by uuid
);


--
-- Name: system_logs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.system_logs (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    level character varying(10) NOT NULL,
    target character varying(255) NOT NULL,
    message text NOT NULL,
    fields jsonb,
    span_id character varying(64),
    node_id character varying(100),
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: TABLE system_logs; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.system_logs IS '系统日志表，存储 DEBUG/WARN/ERROR 级别日志，7天自动清理';


--
-- Name: COLUMN system_logs.level; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_logs.level IS '日志级别: TRACE/DEBUG/INFO/WARN/ERROR';


--
-- Name: COLUMN system_logs.target; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_logs.target IS '日志来源模块路径';


--
-- Name: COLUMN system_logs.message; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_logs.message IS '日志消息内容';


--
-- Name: COLUMN system_logs.fields; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_logs.fields IS '结构化字段 (JSON)';


--
-- Name: COLUMN system_logs.span_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_logs.span_id IS 'Tracing Span ID';


--
-- Name: COLUMN system_logs.node_id; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.system_logs.node_id IS '产生日志的节点标识';


--
-- Name: user_account_limit_settings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_account_limit_settings (
    id integer DEFAULT 1 NOT NULL,
    enable_phone_validation boolean DEFAULT false NOT NULL,
    enable_email_validation boolean DEFAULT false NOT NULL,
    enable_length_validation boolean DEFAULT false NOT NULL,
    min_length integer DEFAULT 3 NOT NULL,
    max_length integer DEFAULT 20 NOT NULL,
    enable_alphanumeric_validation boolean DEFAULT false NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_by uuid
);


--
-- Name: user_emoji_packs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_emoji_packs (
    user_id uuid NOT NULL,
    pack_id uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: user_friend_remarks; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_friend_remarks (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    friend_user_id uuid NOT NULL,
    remark text DEFAULT ''::text NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT user_friend_remarks_check CHECK ((user_id <> friend_user_id))
);


--
-- Name: user_geolocations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_geolocations (
    user_id uuid NOT NULL,
    ip_address inet NOT NULL,
    latitude numeric(10,8),
    longitude numeric(11,8),
    country character varying(100),
    region character varying(100),
    city character varying(100),
    isp character varying(200),
    timezone character varying(50),
    zip_code character varying(20),
    geolocation_source character varying(50) DEFAULT 'ipinfo'::character varying,
    hostname text,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: COLUMN user_geolocations.hostname; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON COLUMN public.user_geolocations.hostname IS '主机名，从ipinfo.io获取';


--
-- Name: user_heartbeat_logs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_heartbeat_logs (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    ip_address inet NOT NULL,
    user_agent text,
    connection_id text NOT NULL,
    heartbeat_at timestamp with time zone DEFAULT now() NOT NULL,
    node_id character varying(100),
    device_info jsonb
);


--
-- Name: TABLE user_heartbeat_logs; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.user_heartbeat_logs IS '用户心跳记录，用于跟踪用户在线状态和IP变化';


--
-- Name: user_login_history; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_login_history (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    ip_address inet NOT NULL,
    user_agent text,
    login_method character varying(50) DEFAULT 'websocket'::character varying NOT NULL,
    login_at timestamp with time zone DEFAULT now() NOT NULL,
    logout_at timestamp with time zone,
    session_duration interval GENERATED ALWAYS AS ((logout_at - login_at)) STORED,
    success boolean DEFAULT true NOT NULL,
    failure_reason text,
    device_info jsonb,
    location_info jsonb
);


--
-- Name: TABLE user_login_history; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.user_login_history IS '用户登录历史记录，用于审计和安全分析';


--
-- Name: user_roles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_roles (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    role_id uuid NOT NULL,
    assigned_by uuid,
    assigned_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: user_room_pins; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_room_pins (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    room_id uuid NOT NULL,
    pinned_at timestamp with time zone DEFAULT now() NOT NULL,
    notification_settings jsonb
);


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id uuid NOT NULL,
    username character varying(50) NOT NULL,
    email character varying(100) NOT NULL,
    password_hash character varying(255) NOT NULL,
    nickname character varying(100),
    avatar_url text,
    avatar_object_key text,
    status smallint DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    deleted_at timestamp with time zone
);


--
-- Data for Name: admin_login_history; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: admin_operation_logs; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: admin_user_roles; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: admin_users; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: app_documents; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: app_versions; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: captcha_settings; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: e2ee_identity_keys; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: e2ee_one_time_pre_keys; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: e2ee_signed_pre_keys; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: emoji_items; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: emoji_packs; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: feedbacks; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: file_upload_audit_tasks; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: file_upload_multipart_sessions; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: file_upload_records; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: friend_requests; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: friendships; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: general_settings; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.general_settings VALUES ('app_name', 'Redcode IM', '应用名称', '2026-04-09 17:08:09.487041+08', NULL);
INSERT INTO public.general_settings VALUES ('ip_geolocation_enabled', '0', '是否启用IP地址地理位置解析功能（0=关闭，1=开启）', '2026-04-09 17:08:09.487041+08', NULL);


--
-- Data for Name: group_admins; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: group_announcements; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: group_invitations; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: group_mutes; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: group_operation_logs; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: group_rules; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: group_settings; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: hot_update_events; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: hot_updates; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: ipinfo_tokens; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: join_requests; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: message_parts; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: message_reactions; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: message_reads; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: messages; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: object_storage_configs; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: permissions; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.permissions VALUES ('75c7670c-25e3-4c05-887d-9e36b9e37cf1', '用户管理', 'user:manage', '管理用户账户', '2026-04-09 17:08:09.487041+08', '2026-04-09 17:08:09.487041+08');
INSERT INTO public.permissions VALUES ('16451f40-742f-4daa-8b4d-c2e0285cf543', '角色管理', 'role:manage', '管理系统角色和权限', '2026-04-09 17:08:09.487041+08', '2026-04-09 17:08:09.487041+08');
INSERT INTO public.permissions VALUES ('c310c244-c202-4707-95e9-31771abe0f6f', '群组管理', 'group:manage', '管理群组和群成员', '2026-04-09 17:08:09.487041+08', '2026-04-09 17:08:09.487041+08');
INSERT INTO public.permissions VALUES ('1bdc23c5-280e-4dd5-9adc-44d6301fb4e9', '消息管理', 'message:manage', '管理聊天消息', '2026-04-09 17:08:09.487041+08', '2026-04-09 17:08:09.487041+08');
INSERT INTO public.permissions VALUES ('86f53e5e-7b0b-493c-8ae2-c28a26216014', '文件管理', 'file:manage', '管理文件上传和存储', '2026-04-09 17:08:09.487041+08', '2026-04-09 17:08:09.487041+08');
INSERT INTO public.permissions VALUES ('73db2f73-2b69-414f-a342-a6ed7f3d4119', '系统设置', 'system:settings', '管理系统配置', '2026-04-09 17:08:09.487041+08', '2026-04-09 17:08:09.487041+08');
INSERT INTO public.permissions VALUES ('2b157cda-aedd-4e81-a778-3157d741df02', '数据分析', 'data:analysis', '查看系统数据和分析报告', '2026-04-09 17:08:09.487041+08', '2026-04-09 17:08:09.487041+08');
INSERT INTO public.permissions VALUES ('bdbf4f15-24d3-4b2f-8058-ff4a921abef4', '日志审计', 'log:audit', '查看系统日志和操作审计', '2026-04-09 17:08:09.487041+08', '2026-04-09 17:08:09.487041+08');


--
-- Data for Name: push_devices; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: push_job_queue; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: push_logs; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: push_provider_configs; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: report_attachments; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: reports; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: role_permissions; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.role_permissions VALUES ('fc738407-1afd-49ee-a79e-83bb41f43d40', '692e81df-c87a-483e-95f1-e316d20be3e0', '75c7670c-25e3-4c05-887d-9e36b9e37cf1', '2026-04-09 17:08:09.487041+08');
INSERT INTO public.role_permissions VALUES ('8009e0a0-2f58-40e6-ac9a-5fba81cde42b', '692e81df-c87a-483e-95f1-e316d20be3e0', '16451f40-742f-4daa-8b4d-c2e0285cf543', '2026-04-09 17:08:09.487041+08');
INSERT INTO public.role_permissions VALUES ('44747a5e-7683-43f1-8b4a-cb1743c02610', '692e81df-c87a-483e-95f1-e316d20be3e0', 'c310c244-c202-4707-95e9-31771abe0f6f', '2026-04-09 17:08:09.487041+08');
INSERT INTO public.role_permissions VALUES ('d6e9c7e2-954b-4cbe-9be1-131d401122ac', '692e81df-c87a-483e-95f1-e316d20be3e0', '1bdc23c5-280e-4dd5-9adc-44d6301fb4e9', '2026-04-09 17:08:09.487041+08');
INSERT INTO public.role_permissions VALUES ('0d8c8ddc-2ced-483b-88eb-1908dc0ca56c', '692e81df-c87a-483e-95f1-e316d20be3e0', '86f53e5e-7b0b-493c-8ae2-c28a26216014', '2026-04-09 17:08:09.487041+08');
INSERT INTO public.role_permissions VALUES ('3a7374d2-5f06-480c-bbb9-5b800081d176', '692e81df-c87a-483e-95f1-e316d20be3e0', '73db2f73-2b69-414f-a342-a6ed7f3d4119', '2026-04-09 17:08:09.487041+08');
INSERT INTO public.role_permissions VALUES ('8f3179fc-dac6-4fff-9478-ea7fbc55a5df', '692e81df-c87a-483e-95f1-e316d20be3e0', '2b157cda-aedd-4e81-a778-3157d741df02', '2026-04-09 17:08:09.487041+08');
INSERT INTO public.role_permissions VALUES ('7fff3d7f-2927-4946-9e9f-455aaa761f2b', '692e81df-c87a-483e-95f1-e316d20be3e0', 'bdbf4f15-24d3-4b2f-8058-ff4a921abef4', '2026-04-09 17:08:09.487041+08');
INSERT INTO public.role_permissions VALUES ('ce80536f-35cc-484e-94ed-33d7b4544785', '879cd9af-d3ef-4fec-bced-5be610937f74', '16451f40-742f-4daa-8b4d-c2e0285cf543', '2026-04-09 17:08:09.487041+08');
INSERT INTO public.role_permissions VALUES ('6d07e7de-6747-4bf6-b112-bbf6f0cd6db9', '879cd9af-d3ef-4fec-bced-5be610937f74', 'c310c244-c202-4707-95e9-31771abe0f6f', '2026-04-09 17:08:09.487041+08');
INSERT INTO public.role_permissions VALUES ('3145589b-8dcb-4821-a0db-d38bbfe3141a', '879cd9af-d3ef-4fec-bced-5be610937f74', '1bdc23c5-280e-4dd5-9adc-44d6301fb4e9', '2026-04-09 17:08:09.487041+08');
INSERT INTO public.role_permissions VALUES ('3eb6d6c4-7719-422c-82f9-b656a3aa3b41', '879cd9af-d3ef-4fec-bced-5be610937f74', '86f53e5e-7b0b-493c-8ae2-c28a26216014', '2026-04-09 17:08:09.487041+08');
INSERT INTO public.role_permissions VALUES ('5fcd6118-d966-4b4b-98e6-9377a07cc969', '879cd9af-d3ef-4fec-bced-5be610937f74', '73db2f73-2b69-414f-a342-a6ed7f3d4119', '2026-04-09 17:08:09.487041+08');
INSERT INTO public.role_permissions VALUES ('253e810a-e2bf-44a7-a252-3c5616f46c63', '879cd9af-d3ef-4fec-bced-5be610937f74', '2b157cda-aedd-4e81-a778-3157d741df02', '2026-04-09 17:08:09.487041+08');
INSERT INTO public.role_permissions VALUES ('f4573f6e-7378-41fe-8c54-895d979b59b8', '879cd9af-d3ef-4fec-bced-5be610937f74', 'bdbf4f15-24d3-4b2f-8058-ff4a921abef4', '2026-04-09 17:08:09.487041+08');
INSERT INTO public.role_permissions VALUES ('05a9818e-1e94-4525-90c0-0ca0945402a0', '6237fa61-1dcb-42b8-9f82-b46a882ccf8c', '75c7670c-25e3-4c05-887d-9e36b9e37cf1', '2026-04-09 17:08:09.487041+08');
INSERT INTO public.role_permissions VALUES ('74d09d2e-8173-48ce-9099-46f4d05ae9e7', '6237fa61-1dcb-42b8-9f82-b46a882ccf8c', 'c310c244-c202-4707-95e9-31771abe0f6f', '2026-04-09 17:08:09.487041+08');
INSERT INTO public.role_permissions VALUES ('3df6af2b-e11d-4fcc-87f5-0fbcef4e4db8', '6237fa61-1dcb-42b8-9f82-b46a882ccf8c', '2b157cda-aedd-4e81-a778-3157d741df02', '2026-04-09 17:08:09.487041+08');


--
-- Data for Name: roles; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.roles VALUES ('692e81df-c87a-483e-95f1-e316d20be3e0', '超级管理员', 'super_admin', '拥有所有权限的超级管理员', true, '2026-04-09 17:08:09.487041+08', '2026-04-09 17:08:09.487041+08');
INSERT INTO public.roles VALUES ('879cd9af-d3ef-4fec-bced-5be610937f74', '管理员', 'admin', '普通管理员，拥有大部分权限', true, '2026-04-09 17:08:09.487041+08', '2026-04-09 17:08:09.487041+08');
INSERT INTO public.roles VALUES ('6237fa61-1dcb-42b8-9f82-b46a882ccf8c', '运营人员', 'operator', '负责日常运营和用户管理', true, '2026-04-09 17:08:09.487041+08', '2026-04-09 17:08:09.487041+08');


--
-- Data for Name: room_members; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: room_pins; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: rooms; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: storage_providers; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: system_logs; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: user_account_limit_settings; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.user_account_limit_settings VALUES (1, true, false, false, 3, 20, false, '2026-04-09 17:08:09.487041+08', NULL);


--
-- Data for Name: user_emoji_packs; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: user_friend_remarks; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: user_geolocations; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: user_heartbeat_logs; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: user_login_history; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: user_roles; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: user_room_pins; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: -
--



--
-- Name: admin_login_history admin_login_history_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admin_login_history
    ADD CONSTRAINT admin_login_history_pkey PRIMARY KEY (id);


--
-- Name: admin_operation_logs admin_operation_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admin_operation_logs
    ADD CONSTRAINT admin_operation_logs_pkey PRIMARY KEY (id);


--
-- Name: admin_user_roles admin_user_roles_admin_user_id_role_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admin_user_roles
    ADD CONSTRAINT admin_user_roles_admin_user_id_role_id_key UNIQUE (admin_user_id, role_id);


--
-- Name: admin_user_roles admin_user_roles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admin_user_roles
    ADD CONSTRAINT admin_user_roles_pkey PRIMARY KEY (id);


--
-- Name: admin_users admin_users_email_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admin_users
    ADD CONSTRAINT admin_users_email_key UNIQUE (email);


--
-- Name: admin_users admin_users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admin_users
    ADD CONSTRAINT admin_users_pkey PRIMARY KEY (id);


--
-- Name: admin_users admin_users_username_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admin_users
    ADD CONSTRAINT admin_users_username_key UNIQUE (username);


--
-- Name: app_documents app_documents_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.app_documents
    ADD CONSTRAINT app_documents_pkey PRIMARY KEY (key);


--
-- Name: app_versions app_versions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.app_versions
    ADD CONSTRAINT app_versions_pkey PRIMARY KEY (id);


--
-- Name: captcha_settings captcha_settings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.captcha_settings
    ADD CONSTRAINT captcha_settings_pkey PRIMARY KEY (key);


--
-- Name: e2ee_identity_keys e2ee_identity_keys_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.e2ee_identity_keys
    ADD CONSTRAINT e2ee_identity_keys_pkey PRIMARY KEY (user_id, device_id);


--
-- Name: e2ee_one_time_pre_keys e2ee_one_time_pre_keys_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.e2ee_one_time_pre_keys
    ADD CONSTRAINT e2ee_one_time_pre_keys_pkey PRIMARY KEY (id);


--
-- Name: e2ee_one_time_pre_keys e2ee_one_time_pre_keys_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.e2ee_one_time_pre_keys
    ADD CONSTRAINT e2ee_one_time_pre_keys_unique UNIQUE (user_id, device_id, key_id);


--
-- Name: e2ee_signed_pre_keys e2ee_signed_pre_keys_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.e2ee_signed_pre_keys
    ADD CONSTRAINT e2ee_signed_pre_keys_pkey PRIMARY KEY (id);


--
-- Name: e2ee_signed_pre_keys e2ee_signed_pre_keys_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.e2ee_signed_pre_keys
    ADD CONSTRAINT e2ee_signed_pre_keys_unique UNIQUE (user_id, device_id, key_id);


--
-- Name: emoji_items emoji_items_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.emoji_items
    ADD CONSTRAINT emoji_items_pkey PRIMARY KEY (id);


--
-- Name: emoji_packs emoji_packs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.emoji_packs
    ADD CONSTRAINT emoji_packs_pkey PRIMARY KEY (id);


--
-- Name: feedbacks feedbacks_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.feedbacks
    ADD CONSTRAINT feedbacks_pkey PRIMARY KEY (id);


--
-- Name: file_upload_audit_tasks file_upload_audit_tasks_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.file_upload_audit_tasks
    ADD CONSTRAINT file_upload_audit_tasks_pkey PRIMARY KEY (id);


--
-- Name: file_upload_multipart_sessions file_upload_multipart_sessions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.file_upload_multipart_sessions
    ADD CONSTRAINT file_upload_multipart_sessions_pkey PRIMARY KEY (id);


--
-- Name: file_upload_records file_upload_records_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.file_upload_records
    ADD CONSTRAINT file_upload_records_pkey PRIMARY KEY (id);


--
-- Name: friend_requests friend_requests_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.friend_requests
    ADD CONSTRAINT friend_requests_pkey PRIMARY KEY (id);


--
-- Name: friend_requests friend_requests_requester_id_addressee_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.friend_requests
    ADD CONSTRAINT friend_requests_requester_id_addressee_id_key UNIQUE (requester_id, addressee_id);


--
-- Name: friendships friendships_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.friendships
    ADD CONSTRAINT friendships_pkey PRIMARY KEY (id);


--
-- Name: friendships friendships_user_a_id_user_b_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.friendships
    ADD CONSTRAINT friendships_user_a_id_user_b_id_key UNIQUE (user_a_id, user_b_id);


--
-- Name: general_settings general_settings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.general_settings
    ADD CONSTRAINT general_settings_pkey PRIMARY KEY (key);


--
-- Name: group_admins group_admins_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.group_admins
    ADD CONSTRAINT group_admins_pkey PRIMARY KEY (id);


--
-- Name: group_admins group_admins_room_id_admin_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.group_admins
    ADD CONSTRAINT group_admins_room_id_admin_id_key UNIQUE (room_id, admin_id);


--
-- Name: group_announcements group_announcements_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.group_announcements
    ADD CONSTRAINT group_announcements_pkey PRIMARY KEY (id);


--
-- Name: group_invitations group_invitations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.group_invitations
    ADD CONSTRAINT group_invitations_pkey PRIMARY KEY (id);


--
-- Name: group_invitations group_invitations_room_id_invitee_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.group_invitations
    ADD CONSTRAINT group_invitations_room_id_invitee_id_key UNIQUE (room_id, invitee_id);


--
-- Name: group_mutes group_mutes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.group_mutes
    ADD CONSTRAINT group_mutes_pkey PRIMARY KEY (id);


--
-- Name: group_mutes group_mutes_room_id_user_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.group_mutes
    ADD CONSTRAINT group_mutes_room_id_user_id_key UNIQUE (room_id, user_id);


--
-- Name: group_operation_logs group_operation_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.group_operation_logs
    ADD CONSTRAINT group_operation_logs_pkey PRIMARY KEY (id);


--
-- Name: group_rules group_rules_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.group_rules
    ADD CONSTRAINT group_rules_pkey PRIMARY KEY (id);


--
-- Name: group_settings group_settings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.group_settings
    ADD CONSTRAINT group_settings_pkey PRIMARY KEY (id);


--
-- Name: group_settings group_settings_room_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.group_settings
    ADD CONSTRAINT group_settings_room_id_key UNIQUE (room_id);


--
-- Name: hot_update_events hot_update_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hot_update_events
    ADD CONSTRAINT hot_update_events_pkey PRIMARY KEY (id);


--
-- Name: hot_updates hot_updates_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hot_updates
    ADD CONSTRAINT hot_updates_pkey PRIMARY KEY (id);


--
-- Name: ipinfo_tokens ipinfo_tokens_name_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ipinfo_tokens
    ADD CONSTRAINT ipinfo_tokens_name_key UNIQUE (name);


--
-- Name: ipinfo_tokens ipinfo_tokens_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ipinfo_tokens
    ADD CONSTRAINT ipinfo_tokens_pkey PRIMARY KEY (id);


--
-- Name: ipinfo_tokens ipinfo_tokens_token_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ipinfo_tokens
    ADD CONSTRAINT ipinfo_tokens_token_key UNIQUE (token);


--
-- Name: join_requests join_requests_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.join_requests
    ADD CONSTRAINT join_requests_pkey PRIMARY KEY (id);


--
-- Name: join_requests join_requests_room_id_applicant_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.join_requests
    ADD CONSTRAINT join_requests_room_id_applicant_id_key UNIQUE (room_id, applicant_id);


--
-- Name: message_parts message_parts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.message_parts
    ADD CONSTRAINT message_parts_pkey PRIMARY KEY (id);


--
-- Name: message_reactions message_reactions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.message_reactions
    ADD CONSTRAINT message_reactions_pkey PRIMARY KEY (id);


--
-- Name: message_reactions message_reactions_unique_user_message_reaction; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.message_reactions
    ADD CONSTRAINT message_reactions_unique_user_message_reaction UNIQUE (message_id, user_id, reaction_key);


--
-- Name: message_reads message_reads_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.message_reads
    ADD CONSTRAINT message_reads_pkey PRIMARY KEY (id);


--
-- Name: messages messages_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT messages_pkey PRIMARY KEY (id);


--
-- Name: object_storage_configs object_storage_configs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.object_storage_configs
    ADD CONSTRAINT object_storage_configs_pkey PRIMARY KEY (id);


--
-- Name: object_storage_configs object_storage_configs_version_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.object_storage_configs
    ADD CONSTRAINT object_storage_configs_version_key UNIQUE (version);


--
-- Name: permissions permissions_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.permissions
    ADD CONSTRAINT permissions_code_key UNIQUE (code);


--
-- Name: permissions permissions_name_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.permissions
    ADD CONSTRAINT permissions_name_key UNIQUE (name);


--
-- Name: permissions permissions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.permissions
    ADD CONSTRAINT permissions_pkey PRIMARY KEY (id);


--
-- Name: push_devices push_devices_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.push_devices
    ADD CONSTRAINT push_devices_pkey PRIMARY KEY (id);


--
-- Name: push_devices push_devices_unique_device_id; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.push_devices
    ADD CONSTRAINT push_devices_unique_device_id UNIQUE (device_id);


--
-- Name: push_devices push_devices_unique_device_token; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.push_devices
    ADD CONSTRAINT push_devices_unique_device_token UNIQUE (device_token);


--
-- Name: push_job_queue push_job_queue_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.push_job_queue
    ADD CONSTRAINT push_job_queue_pkey PRIMARY KEY (id);


--
-- Name: push_logs push_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.push_logs
    ADD CONSTRAINT push_logs_pkey PRIMARY KEY (id);


--
-- Name: push_provider_configs push_provider_configs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.push_provider_configs
    ADD CONSTRAINT push_provider_configs_pkey PRIMARY KEY (id);


--
-- Name: push_provider_configs push_provider_configs_unique; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.push_provider_configs
    ADD CONSTRAINT push_provider_configs_unique UNIQUE (provider, platform);


--
-- Name: report_attachments report_attachments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.report_attachments
    ADD CONSTRAINT report_attachments_pkey PRIMARY KEY (id);


--
-- Name: report_attachments report_attachments_report_id_object_key_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.report_attachments
    ADD CONSTRAINT report_attachments_report_id_object_key_key UNIQUE (report_id, object_key);


--
-- Name: reports reports_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reports
    ADD CONSTRAINT reports_pkey PRIMARY KEY (id);


--
-- Name: role_permissions role_permissions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.role_permissions
    ADD CONSTRAINT role_permissions_pkey PRIMARY KEY (id);


--
-- Name: role_permissions role_permissions_role_id_permission_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.role_permissions
    ADD CONSTRAINT role_permissions_role_id_permission_id_key UNIQUE (role_id, permission_id);


--
-- Name: roles roles_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.roles
    ADD CONSTRAINT roles_code_key UNIQUE (code);


--
-- Name: roles roles_name_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.roles
    ADD CONSTRAINT roles_name_key UNIQUE (name);


--
-- Name: roles roles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.roles
    ADD CONSTRAINT roles_pkey PRIMARY KEY (id);


--
-- Name: room_members room_members_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.room_members
    ADD CONSTRAINT room_members_pkey PRIMARY KEY (id);


--
-- Name: room_pins room_pins_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.room_pins
    ADD CONSTRAINT room_pins_pkey PRIMARY KEY (room_id, message_id);


--
-- Name: rooms rooms_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rooms
    ADD CONSTRAINT rooms_pkey PRIMARY KEY (id);


--
-- Name: storage_providers storage_providers_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.storage_providers
    ADD CONSTRAINT storage_providers_pkey PRIMARY KEY (id);


--
-- Name: system_logs system_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.system_logs
    ADD CONSTRAINT system_logs_pkey PRIMARY KEY (id);


--
-- Name: user_account_limit_settings user_account_limit_settings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_account_limit_settings
    ADD CONSTRAINT user_account_limit_settings_pkey PRIMARY KEY (id);


--
-- Name: user_emoji_packs user_emoji_packs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_emoji_packs
    ADD CONSTRAINT user_emoji_packs_pkey PRIMARY KEY (user_id, pack_id);


--
-- Name: user_friend_remarks user_friend_remarks_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_friend_remarks
    ADD CONSTRAINT user_friend_remarks_pkey PRIMARY KEY (id);


--
-- Name: user_friend_remarks user_friend_remarks_user_id_friend_user_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_friend_remarks
    ADD CONSTRAINT user_friend_remarks_user_id_friend_user_id_key UNIQUE (user_id, friend_user_id);


--
-- Name: user_geolocations user_geolocations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_geolocations
    ADD CONSTRAINT user_geolocations_pkey PRIMARY KEY (user_id);


--
-- Name: user_heartbeat_logs user_heartbeat_logs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_heartbeat_logs
    ADD CONSTRAINT user_heartbeat_logs_pkey PRIMARY KEY (id);


--
-- Name: user_login_history user_login_history_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_login_history
    ADD CONSTRAINT user_login_history_pkey PRIMARY KEY (id);


--
-- Name: user_roles user_roles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_roles
    ADD CONSTRAINT user_roles_pkey PRIMARY KEY (id);


--
-- Name: user_roles user_roles_user_id_role_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_roles
    ADD CONSTRAINT user_roles_user_id_role_id_key UNIQUE (user_id, role_id);


--
-- Name: user_room_pins user_room_pins_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_room_pins
    ADD CONSTRAINT user_room_pins_pkey PRIMARY KEY (id);


--
-- Name: user_room_pins user_room_pins_user_id_room_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_room_pins
    ADD CONSTRAINT user_room_pins_user_id_room_id_key UNIQUE (user_id, room_id);


--
-- Name: users users_email_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_email_key UNIQUE (email);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: users users_username_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_username_key UNIQUE (username);


--
-- Name: idx_admin_login_history_admin_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_admin_login_history_admin_user_id ON public.admin_login_history USING btree (admin_user_id);


--
-- Name: idx_admin_login_history_login_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_admin_login_history_login_at ON public.admin_login_history USING btree (login_at);


--
-- Name: idx_admin_operation_logs_admin_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_admin_operation_logs_admin_user_id ON public.admin_operation_logs USING btree (admin_user_id);


--
-- Name: idx_admin_operation_logs_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_admin_operation_logs_created_at ON public.admin_operation_logs USING btree (created_at);


--
-- Name: idx_admin_user_roles_admin_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_admin_user_roles_admin_user_id ON public.admin_user_roles USING btree (admin_user_id);


--
-- Name: idx_admin_user_roles_role_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_admin_user_roles_role_id ON public.admin_user_roles USING btree (role_id);


--
-- Name: idx_admin_users_deleted_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_admin_users_deleted_at ON public.admin_users USING btree (deleted_at);


--
-- Name: idx_admin_users_email; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_admin_users_email ON public.admin_users USING btree (email);


--
-- Name: idx_admin_users_email_lower; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_admin_users_email_lower ON public.admin_users USING btree (lower((email)::text));


--
-- Name: idx_admin_users_last_login_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_admin_users_last_login_at ON public.admin_users USING btree (last_login_at);


--
-- Name: idx_admin_users_locked_until; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_admin_users_locked_until ON public.admin_users USING btree (locked_until);


--
-- Name: idx_admin_users_nickname_lower; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_admin_users_nickname_lower ON public.admin_users USING btree (lower((COALESCE(nickname, ''::character varying))::text));


--
-- Name: idx_admin_users_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_admin_users_status ON public.admin_users USING btree (status);


--
-- Name: idx_admin_users_username; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_admin_users_username ON public.admin_users USING btree (username);


--
-- Name: idx_admin_users_username_lower; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_admin_users_username_lower ON public.admin_users USING btree (lower((username)::text));


--
-- Name: idx_app_documents_updated_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_app_documents_updated_at ON public.app_documents USING btree (updated_at DESC);


--
-- Name: idx_app_versions_list; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_app_versions_list ON public.app_versions USING btree (platform, is_active, released_at DESC);


--
-- Name: idx_app_versions_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_app_versions_unique ON public.app_versions USING btree (platform, channel, version);


--
-- Name: idx_e2ee_identity_keys_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_e2ee_identity_keys_user ON public.e2ee_identity_keys USING btree (user_id);


--
-- Name: idx_e2ee_one_time_pre_keys_unused; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_e2ee_one_time_pre_keys_unused ON public.e2ee_one_time_pre_keys USING btree (user_id, device_id, created_at) WHERE (is_used IS FALSE);


--
-- Name: idx_e2ee_signed_pre_keys_user_device_expires; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_e2ee_signed_pre_keys_user_device_expires ON public.e2ee_signed_pre_keys USING btree (user_id, device_id, expires_at);


--
-- Name: idx_emoji_items_pack_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_emoji_items_pack_id ON public.emoji_items USING btree (pack_id);


--
-- Name: idx_emoji_items_sort_order; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_emoji_items_sort_order ON public.emoji_items USING btree (pack_id, sort_order);


--
-- Name: idx_emoji_packs_is_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_emoji_packs_is_active ON public.emoji_packs USING btree (is_active);


--
-- Name: idx_emoji_packs_pack_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_emoji_packs_pack_type ON public.emoji_packs USING btree (pack_type);


--
-- Name: idx_emoji_packs_parent_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_emoji_packs_parent_id ON public.emoji_packs USING btree (parent_id);


--
-- Name: idx_feedbacks_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_feedbacks_created_at ON public.feedbacks USING btree (created_at DESC);


--
-- Name: idx_feedbacks_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_feedbacks_user_id ON public.feedbacks USING btree (user_id);


--
-- Name: idx_file_upload_audit_tasks_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_file_upload_audit_tasks_created_at ON public.file_upload_audit_tasks USING btree (created_at DESC);


--
-- Name: idx_file_upload_audit_tasks_provider_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_file_upload_audit_tasks_provider_key ON public.file_upload_audit_tasks USING btree (storage_provider_id, object_key);


--
-- Name: idx_file_upload_audit_tasks_status_next; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_file_upload_audit_tasks_status_next ON public.file_upload_audit_tasks USING btree (status, next_run_at);


--
-- Name: idx_file_upload_multipart_sessions_creator; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_file_upload_multipart_sessions_creator ON public.file_upload_multipart_sessions USING btree (creator_id, creator_is_admin);


--
-- Name: idx_file_upload_multipart_sessions_status_updated; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_file_upload_multipart_sessions_status_updated ON public.file_upload_multipart_sessions USING btree (status, updated_at DESC);


--
-- Name: idx_file_upload_multipart_sessions_unique_upload; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_file_upload_multipart_sessions_unique_upload ON public.file_upload_multipart_sessions USING btree (storage_provider_id, object_key, upload_id);


--
-- Name: idx_file_upload_records_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_file_upload_records_created_at ON public.file_upload_records USING btree (created_at);


--
-- Name: idx_file_upload_records_hash_completed; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_file_upload_records_hash_completed ON public.file_upload_records USING btree (hash_alg, hash_value, file_size, status);


--
-- Name: idx_file_upload_records_provider_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_file_upload_records_provider_key ON public.file_upload_records USING btree (storage_provider_id, object_key);


--
-- Name: idx_friend_requests_add_status_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_friend_requests_add_status_created ON public.friend_requests USING btree (addressee_id, status, created_at DESC);


--
-- Name: idx_friend_requests_addressee; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_friend_requests_addressee ON public.friend_requests USING btree (addressee_id);


--
-- Name: idx_friend_requests_req_status_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_friend_requests_req_status_created ON public.friend_requests USING btree (requester_id, status, created_at DESC);


--
-- Name: idx_friend_requests_requester; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_friend_requests_requester ON public.friend_requests USING btree (requester_id);


--
-- Name: idx_friend_requests_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_friend_requests_status ON public.friend_requests USING btree (status);


--
-- Name: idx_friendships_user_a; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_friendships_user_a ON public.friendships USING btree (user_a_id);


--
-- Name: idx_friendships_user_b; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_friendships_user_b ON public.friendships USING btree (user_b_id);


--
-- Name: idx_group_admins_admin_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_group_admins_admin_id ON public.group_admins USING btree (admin_id);


--
-- Name: idx_group_admins_room_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_group_admins_room_id ON public.group_admins USING btree (room_id);


--
-- Name: idx_group_announcements_pinned; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_group_announcements_pinned ON public.group_announcements USING btree (is_pinned);


--
-- Name: idx_group_announcements_room_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_group_announcements_room_id ON public.group_announcements USING btree (room_id);


--
-- Name: idx_group_invitations_room_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_group_invitations_room_id ON public.group_invitations USING btree (room_id);


--
-- Name: idx_group_invitations_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_group_invitations_status ON public.group_invitations USING btree (status);


--
-- Name: idx_group_mutes_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_group_mutes_active ON public.group_mutes USING btree (is_active);


--
-- Name: idx_group_mutes_room_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_group_mutes_room_id ON public.group_mutes USING btree (room_id);


--
-- Name: idx_group_mutes_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_group_mutes_user_id ON public.group_mutes USING btree (user_id);


--
-- Name: idx_group_operation_logs_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_group_operation_logs_created_at ON public.group_operation_logs USING btree (created_at);


--
-- Name: idx_group_operation_logs_room_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_group_operation_logs_room_id ON public.group_operation_logs USING btree (room_id);


--
-- Name: idx_group_rules_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_group_rules_active ON public.group_rules USING btree (is_active);


--
-- Name: idx_group_rules_room_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_group_rules_room_id ON public.group_rules USING btree (room_id);


--
-- Name: idx_group_settings_global_mute; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_group_settings_global_mute ON public.group_settings USING btree (global_mute_enabled);


--
-- Name: idx_group_settings_room_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_group_settings_room_id ON public.group_settings USING btree (room_id);


--
-- Name: idx_hot_update_events_client_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_hot_update_events_client_type ON public.hot_update_events USING btree (client_type);


--
-- Name: idx_hot_update_events_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_hot_update_events_created_at ON public.hot_update_events USING btree (created_at DESC);


--
-- Name: idx_hot_update_events_os_version; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_hot_update_events_os_version ON public.hot_update_events USING btree (os_version);


--
-- Name: idx_hot_update_events_platform_client_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_hot_update_events_platform_client_type ON public.hot_update_events USING btree (platform, client_type);


--
-- Name: idx_hot_updates_lookup; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_hot_updates_lookup ON public.hot_updates USING btree (platform, channel, is_active, released_at DESC NULLS LAST);


--
-- Name: idx_hot_updates_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_hot_updates_unique ON public.hot_updates USING btree (app_version_id, patch_version);


--
-- Name: idx_ipinfo_tokens_last_used_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_ipinfo_tokens_last_used_at ON public.ipinfo_tokens USING btree (last_used_at);


--
-- Name: idx_ipinfo_tokens_reset_date; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_ipinfo_tokens_reset_date ON public.ipinfo_tokens USING btree (reset_date);


--
-- Name: idx_ipinfo_tokens_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_ipinfo_tokens_status ON public.ipinfo_tokens USING btree (status);


--
-- Name: idx_join_requests_room_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_join_requests_room_id ON public.join_requests USING btree (room_id);


--
-- Name: idx_join_requests_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_join_requests_status ON public.join_requests USING btree (status);


--
-- Name: idx_message_parts_message_id_position; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_message_parts_message_id_position ON public.message_parts USING btree (message_id, "position");


--
-- Name: idx_message_reactions_message_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_message_reactions_message_id ON public.message_reactions USING btree (message_id) WHERE (deleted_at IS NULL);


--
-- Name: idx_message_reactions_message_reaction; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_message_reactions_message_reaction ON public.message_reactions USING btree (message_id, reaction_key) WHERE (deleted_at IS NULL);


--
-- Name: idx_message_reactions_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_message_reactions_user_id ON public.message_reactions USING btree (user_id) WHERE (deleted_at IS NULL);


--
-- Name: idx_message_reads_message_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_message_reads_message_id ON public.message_reads USING btree (message_id);


--
-- Name: idx_message_reads_message_read_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_message_reads_message_read_at ON public.message_reads USING btree (message_id, read_at);


--
-- Name: idx_message_reads_read_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_message_reads_read_at ON public.message_reads USING btree (read_at);


--
-- Name: idx_message_reads_room_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_message_reads_room_id ON public.message_reads USING btree (room_id);


--
-- Name: idx_message_reads_room_user_message; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_message_reads_room_user_message ON public.message_reads USING btree (room_id, user_id, message_id);


--
-- Name: idx_message_reads_unique_message_user; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_message_reads_unique_message_user ON public.message_reads USING btree (message_id, user_id);


--
-- Name: idx_message_reads_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_message_reads_user_id ON public.message_reads USING btree (user_id);


--
-- Name: idx_message_reads_user_room; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_message_reads_user_room ON public.message_reads USING btree (user_id, room_id);


--
-- Name: idx_messages_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_messages_created_at ON public.messages USING btree (created_at);


--
-- Name: idx_messages_deleted_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_messages_deleted_at ON public.messages USING btree (deleted_at);


--
-- Name: idx_messages_edited_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_messages_edited_at ON public.messages USING btree (edited_at) WHERE (edited_at IS NOT NULL);


--
-- Name: idx_messages_forward_from_message; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_messages_forward_from_message ON public.messages USING btree (forward_from_message_id) WHERE (forward_from_message_id IS NOT NULL);


--
-- Name: idx_messages_quoted_message_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_messages_quoted_message_id ON public.messages USING btree (quoted_message_id);


--
-- Name: idx_messages_room_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_messages_room_created_at ON public.messages USING btree (room_id, created_at) WHERE (deleted_at IS NULL);


--
-- Name: idx_messages_room_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_messages_room_id ON public.messages USING btree (room_id);


--
-- Name: idx_messages_sender_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_messages_sender_id ON public.messages USING btree (sender_id);


--
-- Name: idx_object_storage_configs_active_unique; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_object_storage_configs_active_unique ON public.object_storage_configs USING btree (status) WHERE ((status)::text = 'active'::text);


--
-- Name: idx_object_storage_configs_provider; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_object_storage_configs_provider ON public.object_storage_configs USING btree (provider);


--
-- Name: idx_object_storage_configs_rollback_source_version; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_object_storage_configs_rollback_source_version ON public.object_storage_configs USING btree (rollback_source_version);


--
-- Name: idx_object_storage_configs_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_object_storage_configs_status ON public.object_storage_configs USING btree (status);


--
-- Name: idx_permissions_code; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_permissions_code ON public.permissions USING btree (code);


--
-- Name: idx_push_devices_channel_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_push_devices_channel_active ON public.push_devices USING btree (channel) WHERE (is_active IS TRUE);


--
-- Name: idx_push_devices_user_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_push_devices_user_active ON public.push_devices USING btree (user_id) WHERE (is_active IS TRUE);


--
-- Name: idx_push_job_queue_due; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_push_job_queue_due ON public.push_job_queue USING btree (status, next_run_at, created_at);


--
-- Name: idx_push_logs_push_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_push_logs_push_id ON public.push_logs USING btree (push_id);


--
-- Name: idx_push_logs_success_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_push_logs_success_created ON public.push_logs USING btree (success, created_at DESC);


--
-- Name: idx_push_logs_user_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_push_logs_user_created ON public.push_logs USING btree (user_id, created_at DESC);


--
-- Name: idx_push_provider_configs_enabled; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_push_provider_configs_enabled ON public.push_provider_configs USING btree (enabled);


--
-- Name: idx_push_provider_configs_provider; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_push_provider_configs_provider ON public.push_provider_configs USING btree (provider);


--
-- Name: idx_report_attachments_object_key; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_report_attachments_object_key ON public.report_attachments USING btree (object_key);


--
-- Name: idx_report_attachments_report_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_report_attachments_report_id ON public.report_attachments USING btree (report_id);


--
-- Name: idx_reports_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_reports_created_at ON public.reports USING btree (created_at DESC);


--
-- Name: idx_reports_reporter_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_reports_reporter_id ON public.reports USING btree (reporter_id);


--
-- Name: idx_reports_target_room_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_reports_target_room_id ON public.reports USING btree (target_room_id);


--
-- Name: idx_reports_target_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_reports_target_type ON public.reports USING btree (target_type);


--
-- Name: idx_reports_target_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_reports_target_user_id ON public.reports USING btree (target_user_id);


--
-- Name: idx_role_permissions_permission_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_role_permissions_permission_id ON public.role_permissions USING btree (permission_id);


--
-- Name: idx_role_permissions_role_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_role_permissions_role_id ON public.role_permissions USING btree (role_id);


--
-- Name: idx_roles_code; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_roles_code ON public.roles USING btree (code);


--
-- Name: idx_room_members_deleted_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_room_members_deleted_at ON public.room_members USING btree (deleted_at);


--
-- Name: idx_room_members_last_read_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_room_members_last_read_at ON public.room_members USING btree (last_read_at);


--
-- Name: idx_room_members_notification_settings; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_room_members_notification_settings ON public.room_members USING btree (notification_settings);


--
-- Name: idx_room_members_role; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_room_members_role ON public.room_members USING btree (role);


--
-- Name: idx_room_members_room_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_room_members_room_id ON public.room_members USING btree (room_id);


--
-- Name: idx_room_members_unique_active; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_room_members_unique_active ON public.room_members USING btree (room_id, user_id) WHERE (deleted_at IS NULL);


--
-- Name: idx_room_members_user_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_room_members_user_active ON public.room_members USING btree (user_id) WHERE (deleted_at IS NULL);


--
-- Name: idx_room_members_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_room_members_user_id ON public.room_members USING btree (user_id);


--
-- Name: idx_room_pins_message_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_room_pins_message_id ON public.room_pins USING btree (message_id);


--
-- Name: idx_rooms_deleted_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_rooms_deleted_at ON public.rooms USING btree (deleted_at);


--
-- Name: idx_rooms_owner_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_rooms_owner_id ON public.rooms USING btree (owner_id);


--
-- Name: idx_rooms_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_rooms_type ON public.rooms USING btree (room_type);


--
-- Name: idx_storage_providers_active; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_storage_providers_active ON public.storage_providers USING btree (is_active);


--
-- Name: idx_storage_providers_default; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_storage_providers_default ON public.storage_providers USING btree (is_default);


--
-- Name: idx_storage_providers_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_storage_providers_type ON public.storage_providers USING btree (provider_type);


--
-- Name: idx_storage_providers_unique_default; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX idx_storage_providers_unique_default ON public.storage_providers USING btree (is_default) WHERE (is_default = true);


--
-- Name: idx_system_logs_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_system_logs_created_at ON public.system_logs USING btree (created_at DESC);


--
-- Name: idx_system_logs_level; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_system_logs_level ON public.system_logs USING btree (level);


--
-- Name: idx_system_logs_level_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_system_logs_level_created ON public.system_logs USING btree (level, created_at DESC);


--
-- Name: idx_system_logs_target; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_system_logs_target ON public.system_logs USING btree (target);


--
-- Name: idx_user_emoji_packs_pack_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_user_emoji_packs_pack_id ON public.user_emoji_packs USING btree (pack_id);


--
-- Name: idx_user_emoji_packs_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_user_emoji_packs_user_id ON public.user_emoji_packs USING btree (user_id);


--
-- Name: idx_user_friend_remarks_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_user_friend_remarks_user_id ON public.user_friend_remarks USING btree (user_id) WHERE (remark <> ''::text);


--
-- Name: idx_user_geolocations_city; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_user_geolocations_city ON public.user_geolocations USING btree (city);


--
-- Name: idx_user_geolocations_country; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_user_geolocations_country ON public.user_geolocations USING btree (country);


--
-- Name: idx_user_geolocations_ip; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_user_geolocations_ip ON public.user_geolocations USING btree (ip_address);


--
-- Name: idx_user_geolocations_updated_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_user_geolocations_updated_at ON public.user_geolocations USING btree (updated_at);


--
-- Name: idx_user_heartbeat_logs_connection_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_user_heartbeat_logs_connection_id ON public.user_heartbeat_logs USING btree (connection_id);


--
-- Name: idx_user_heartbeat_logs_heartbeat_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_user_heartbeat_logs_heartbeat_at ON public.user_heartbeat_logs USING btree (heartbeat_at);


--
-- Name: idx_user_heartbeat_logs_ip_address; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_user_heartbeat_logs_ip_address ON public.user_heartbeat_logs USING btree (ip_address);


--
-- Name: idx_user_heartbeat_logs_user_heartbeat_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_user_heartbeat_logs_user_heartbeat_at ON public.user_heartbeat_logs USING btree (user_id, heartbeat_at DESC);


--
-- Name: idx_user_heartbeat_logs_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_user_heartbeat_logs_user_id ON public.user_heartbeat_logs USING btree (user_id);


--
-- Name: idx_user_login_history_ip_address; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_user_login_history_ip_address ON public.user_login_history USING btree (ip_address);


--
-- Name: idx_user_login_history_ip_login_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_user_login_history_ip_login_at ON public.user_login_history USING btree (ip_address, login_at DESC);


--
-- Name: idx_user_login_history_login_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_user_login_history_login_at ON public.user_login_history USING btree (login_at);


--
-- Name: idx_user_login_history_logout_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_user_login_history_logout_at ON public.user_login_history USING btree (logout_at) WHERE (logout_at IS NOT NULL);


--
-- Name: idx_user_login_history_success; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_user_login_history_success ON public.user_login_history USING btree (success);


--
-- Name: idx_user_login_history_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_user_login_history_user_id ON public.user_login_history USING btree (user_id);


--
-- Name: idx_user_login_history_user_login_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_user_login_history_user_login_at ON public.user_login_history USING btree (user_id, login_at DESC);


--
-- Name: idx_user_roles_role_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_user_roles_role_id ON public.user_roles USING btree (role_id);


--
-- Name: idx_user_roles_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_user_roles_user_id ON public.user_roles USING btree (user_id);


--
-- Name: idx_user_room_pins_pinned_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_user_room_pins_pinned_at ON public.user_room_pins USING btree (pinned_at);


--
-- Name: idx_user_room_pins_room_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_user_room_pins_room_id ON public.user_room_pins USING btree (room_id);


--
-- Name: idx_user_room_pins_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_user_room_pins_user_id ON public.user_room_pins USING btree (user_id);


--
-- Name: idx_users_deleted_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_users_deleted_at ON public.users USING btree (deleted_at);


--
-- Name: idx_users_email; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_users_email ON public.users USING btree (email);


--
-- Name: idx_users_email_lower; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_users_email_lower ON public.users USING btree (lower((email)::text));


--
-- Name: idx_users_nickname_lower; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_users_nickname_lower ON public.users USING btree (lower((COALESCE(nickname, ''::character varying))::text));


--
-- Name: idx_users_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_users_status ON public.users USING btree (status);


--
-- Name: idx_users_username; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_users_username ON public.users USING btree (username);


--
-- Name: idx_users_username_lower; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_users_username_lower ON public.users USING btree (lower((username)::text));


--
-- Name: group_announcements update_group_announcements_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER update_group_announcements_updated_at BEFORE UPDATE ON public.group_announcements FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: group_rules update_group_rules_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER update_group_rules_updated_at BEFORE UPDATE ON public.group_rules FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: group_settings update_group_settings_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER update_group_settings_updated_at BEFORE UPDATE ON public.group_settings FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: permissions update_permissions_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER update_permissions_updated_at BEFORE UPDATE ON public.permissions FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: roles update_roles_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER update_roles_updated_at BEFORE UPDATE ON public.roles FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


--
-- Name: admin_login_history admin_login_history_admin_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admin_login_history
    ADD CONSTRAINT admin_login_history_admin_user_id_fkey FOREIGN KEY (admin_user_id) REFERENCES public.admin_users(id) ON DELETE CASCADE;


--
-- Name: admin_operation_logs admin_operation_logs_admin_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admin_operation_logs
    ADD CONSTRAINT admin_operation_logs_admin_user_id_fkey FOREIGN KEY (admin_user_id) REFERENCES public.admin_users(id) ON DELETE SET NULL;


--
-- Name: admin_user_roles admin_user_roles_admin_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admin_user_roles
    ADD CONSTRAINT admin_user_roles_admin_user_id_fkey FOREIGN KEY (admin_user_id) REFERENCES public.admin_users(id) ON DELETE CASCADE;


--
-- Name: admin_user_roles admin_user_roles_assigned_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admin_user_roles
    ADD CONSTRAINT admin_user_roles_assigned_by_fkey FOREIGN KEY (assigned_by) REFERENCES public.admin_users(id);


--
-- Name: admin_user_roles admin_user_roles_role_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admin_user_roles
    ADD CONSTRAINT admin_user_roles_role_id_fkey FOREIGN KEY (role_id) REFERENCES public.roles(id) ON DELETE CASCADE;


--
-- Name: app_documents app_documents_updated_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.app_documents
    ADD CONSTRAINT app_documents_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES public.admin_users(id) ON DELETE SET NULL;


--
-- Name: captcha_settings captcha_settings_updated_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.captcha_settings
    ADD CONSTRAINT captcha_settings_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES public.admin_users(id) ON DELETE SET NULL;


--
-- Name: e2ee_identity_keys e2ee_identity_keys_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.e2ee_identity_keys
    ADD CONSTRAINT e2ee_identity_keys_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: e2ee_one_time_pre_keys e2ee_one_time_pre_keys_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.e2ee_one_time_pre_keys
    ADD CONSTRAINT e2ee_one_time_pre_keys_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: e2ee_signed_pre_keys e2ee_signed_pre_keys_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.e2ee_signed_pre_keys
    ADD CONSTRAINT e2ee_signed_pre_keys_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: emoji_items emoji_items_pack_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.emoji_items
    ADD CONSTRAINT emoji_items_pack_id_fkey FOREIGN KEY (pack_id) REFERENCES public.emoji_packs(id) ON DELETE CASCADE;


--
-- Name: emoji_packs emoji_packs_parent_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.emoji_packs
    ADD CONSTRAINT emoji_packs_parent_id_fkey FOREIGN KEY (parent_id) REFERENCES public.emoji_packs(id) ON DELETE CASCADE;


--
-- Name: feedbacks feedbacks_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.feedbacks
    ADD CONSTRAINT feedbacks_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: file_upload_audit_tasks file_upload_audit_tasks_storage_provider_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.file_upload_audit_tasks
    ADD CONSTRAINT file_upload_audit_tasks_storage_provider_id_fkey FOREIGN KEY (storage_provider_id) REFERENCES public.storage_providers(id) ON DELETE RESTRICT;


--
-- Name: file_upload_multipart_sessions file_upload_multipart_sessions_storage_provider_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.file_upload_multipart_sessions
    ADD CONSTRAINT file_upload_multipart_sessions_storage_provider_id_fkey FOREIGN KEY (storage_provider_id) REFERENCES public.storage_providers(id) ON DELETE RESTRICT;


--
-- Name: file_upload_records file_upload_records_storage_provider_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.file_upload_records
    ADD CONSTRAINT file_upload_records_storage_provider_id_fkey FOREIGN KEY (storage_provider_id) REFERENCES public.storage_providers(id) ON DELETE RESTRICT;


--
-- Name: friend_requests friend_requests_addressee_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.friend_requests
    ADD CONSTRAINT friend_requests_addressee_id_fkey FOREIGN KEY (addressee_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: friend_requests friend_requests_requester_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.friend_requests
    ADD CONSTRAINT friend_requests_requester_id_fkey FOREIGN KEY (requester_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: friendships friendships_user_a_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.friendships
    ADD CONSTRAINT friendships_user_a_id_fkey FOREIGN KEY (user_a_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: friendships friendships_user_b_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.friendships
    ADD CONSTRAINT friendships_user_b_id_fkey FOREIGN KEY (user_b_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: general_settings general_settings_updated_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.general_settings
    ADD CONSTRAINT general_settings_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES public.admin_users(id) ON DELETE SET NULL;


--
-- Name: group_admins group_admins_admin_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.group_admins
    ADD CONSTRAINT group_admins_admin_id_fkey FOREIGN KEY (admin_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: group_admins group_admins_appointed_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.group_admins
    ADD CONSTRAINT group_admins_appointed_by_fkey FOREIGN KEY (appointed_by) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: group_admins group_admins_room_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.group_admins
    ADD CONSTRAINT group_admins_room_id_fkey FOREIGN KEY (room_id) REFERENCES public.rooms(id) ON DELETE CASCADE;


--
-- Name: group_announcements group_announcements_publisher_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.group_announcements
    ADD CONSTRAINT group_announcements_publisher_id_fkey FOREIGN KEY (publisher_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: group_announcements group_announcements_room_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.group_announcements
    ADD CONSTRAINT group_announcements_room_id_fkey FOREIGN KEY (room_id) REFERENCES public.rooms(id) ON DELETE CASCADE;


--
-- Name: group_invitations group_invitations_invitee_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.group_invitations
    ADD CONSTRAINT group_invitations_invitee_id_fkey FOREIGN KEY (invitee_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: group_invitations group_invitations_inviter_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.group_invitations
    ADD CONSTRAINT group_invitations_inviter_id_fkey FOREIGN KEY (inviter_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: group_invitations group_invitations_room_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.group_invitations
    ADD CONSTRAINT group_invitations_room_id_fkey FOREIGN KEY (room_id) REFERENCES public.rooms(id) ON DELETE CASCADE;


--
-- Name: group_mutes group_mutes_muted_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.group_mutes
    ADD CONSTRAINT group_mutes_muted_by_fkey FOREIGN KEY (muted_by) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: group_mutes group_mutes_room_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.group_mutes
    ADD CONSTRAINT group_mutes_room_id_fkey FOREIGN KEY (room_id) REFERENCES public.rooms(id) ON DELETE CASCADE;


--
-- Name: group_mutes group_mutes_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.group_mutes
    ADD CONSTRAINT group_mutes_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: group_operation_logs group_operation_logs_operator_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.group_operation_logs
    ADD CONSTRAINT group_operation_logs_operator_id_fkey FOREIGN KEY (operator_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: group_operation_logs group_operation_logs_room_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.group_operation_logs
    ADD CONSTRAINT group_operation_logs_room_id_fkey FOREIGN KEY (room_id) REFERENCES public.rooms(id) ON DELETE CASCADE;


--
-- Name: group_operation_logs group_operation_logs_target_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.group_operation_logs
    ADD CONSTRAINT group_operation_logs_target_user_id_fkey FOREIGN KEY (target_user_id) REFERENCES public.users(id);


--
-- Name: group_rules group_rules_creator_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.group_rules
    ADD CONSTRAINT group_rules_creator_id_fkey FOREIGN KEY (creator_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: group_rules group_rules_room_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.group_rules
    ADD CONSTRAINT group_rules_room_id_fkey FOREIGN KEY (room_id) REFERENCES public.rooms(id) ON DELETE CASCADE;


--
-- Name: group_settings group_settings_global_mute_set_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.group_settings
    ADD CONSTRAINT group_settings_global_mute_set_by_fkey FOREIGN KEY (global_mute_set_by) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: group_settings group_settings_room_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.group_settings
    ADD CONSTRAINT group_settings_room_id_fkey FOREIGN KEY (room_id) REFERENCES public.rooms(id) ON DELETE CASCADE;


--
-- Name: hot_updates hot_updates_app_version_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hot_updates
    ADD CONSTRAINT hot_updates_app_version_id_fkey FOREIGN KEY (app_version_id) REFERENCES public.app_versions(id) ON DELETE CASCADE;


--
-- Name: join_requests join_requests_applicant_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.join_requests
    ADD CONSTRAINT join_requests_applicant_id_fkey FOREIGN KEY (applicant_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: join_requests join_requests_reviewer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.join_requests
    ADD CONSTRAINT join_requests_reviewer_id_fkey FOREIGN KEY (reviewer_id) REFERENCES public.users(id);


--
-- Name: join_requests join_requests_room_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.join_requests
    ADD CONSTRAINT join_requests_room_id_fkey FOREIGN KEY (room_id) REFERENCES public.rooms(id) ON DELETE CASCADE;


--
-- Name: message_parts message_parts_message_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.message_parts
    ADD CONSTRAINT message_parts_message_id_fkey FOREIGN KEY (message_id) REFERENCES public.messages(id) ON DELETE CASCADE;


--
-- Name: message_reactions message_reactions_message_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.message_reactions
    ADD CONSTRAINT message_reactions_message_id_fkey FOREIGN KEY (message_id) REFERENCES public.messages(id) ON DELETE CASCADE;


--
-- Name: message_reactions message_reactions_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.message_reactions
    ADD CONSTRAINT message_reactions_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: message_reads message_reads_message_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.message_reads
    ADD CONSTRAINT message_reads_message_id_fkey FOREIGN KEY (message_id) REFERENCES public.messages(id) ON DELETE CASCADE;


--
-- Name: message_reads message_reads_room_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.message_reads
    ADD CONSTRAINT message_reads_room_id_fkey FOREIGN KEY (room_id) REFERENCES public.rooms(id) ON DELETE CASCADE;


--
-- Name: message_reads message_reads_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.message_reads
    ADD CONSTRAINT message_reads_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: messages messages_quoted_message_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT messages_quoted_message_id_fkey FOREIGN KEY (quoted_message_id) REFERENCES public.messages(id) ON DELETE SET NULL;


--
-- Name: messages messages_room_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT messages_room_id_fkey FOREIGN KEY (room_id) REFERENCES public.rooms(id) ON DELETE CASCADE;


--
-- Name: messages messages_sender_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.messages
    ADD CONSTRAINT messages_sender_id_fkey FOREIGN KEY (sender_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: push_devices push_devices_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.push_devices
    ADD CONSTRAINT push_devices_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: push_logs push_logs_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.push_logs
    ADD CONSTRAINT push_logs_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: push_provider_configs push_provider_configs_updated_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.push_provider_configs
    ADD CONSTRAINT push_provider_configs_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES public.admin_users(id) ON DELETE SET NULL;


--
-- Name: report_attachments report_attachments_report_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.report_attachments
    ADD CONSTRAINT report_attachments_report_id_fkey FOREIGN KEY (report_id) REFERENCES public.reports(id) ON DELETE CASCADE;


--
-- Name: reports reports_reporter_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reports
    ADD CONSTRAINT reports_reporter_id_fkey FOREIGN KEY (reporter_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: reports reports_target_room_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reports
    ADD CONSTRAINT reports_target_room_id_fkey FOREIGN KEY (target_room_id) REFERENCES public.rooms(id) ON DELETE CASCADE;


--
-- Name: reports reports_target_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reports
    ADD CONSTRAINT reports_target_user_id_fkey FOREIGN KEY (target_user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: role_permissions role_permissions_permission_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.role_permissions
    ADD CONSTRAINT role_permissions_permission_id_fkey FOREIGN KEY (permission_id) REFERENCES public.permissions(id) ON DELETE CASCADE;


--
-- Name: role_permissions role_permissions_role_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.role_permissions
    ADD CONSTRAINT role_permissions_role_id_fkey FOREIGN KEY (role_id) REFERENCES public.roles(id) ON DELETE CASCADE;


--
-- Name: room_members room_members_last_read_message_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.room_members
    ADD CONSTRAINT room_members_last_read_message_id_fkey FOREIGN KEY (last_read_message_id) REFERENCES public.messages(id);


--
-- Name: room_members room_members_room_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.room_members
    ADD CONSTRAINT room_members_room_id_fkey FOREIGN KEY (room_id) REFERENCES public.rooms(id) ON DELETE CASCADE;


--
-- Name: room_members room_members_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.room_members
    ADD CONSTRAINT room_members_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: room_pins room_pins_message_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.room_pins
    ADD CONSTRAINT room_pins_message_id_fkey FOREIGN KEY (message_id) REFERENCES public.messages(id) ON DELETE CASCADE;


--
-- Name: room_pins room_pins_pinned_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.room_pins
    ADD CONSTRAINT room_pins_pinned_by_fkey FOREIGN KEY (pinned_by) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: room_pins room_pins_room_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.room_pins
    ADD CONSTRAINT room_pins_room_id_fkey FOREIGN KEY (room_id) REFERENCES public.rooms(id) ON DELETE CASCADE;


--
-- Name: rooms rooms_owner_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.rooms
    ADD CONSTRAINT rooms_owner_id_fkey FOREIGN KEY (owner_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: storage_providers storage_providers_updated_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.storage_providers
    ADD CONSTRAINT storage_providers_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES public.admin_users(id) ON DELETE SET NULL;


--
-- Name: user_account_limit_settings user_account_limit_settings_updated_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_account_limit_settings
    ADD CONSTRAINT user_account_limit_settings_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES public.admin_users(id) ON DELETE SET NULL;


--
-- Name: user_emoji_packs user_emoji_packs_pack_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_emoji_packs
    ADD CONSTRAINT user_emoji_packs_pack_id_fkey FOREIGN KEY (pack_id) REFERENCES public.emoji_packs(id) ON DELETE CASCADE;


--
-- Name: user_emoji_packs user_emoji_packs_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_emoji_packs
    ADD CONSTRAINT user_emoji_packs_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: user_friend_remarks user_friend_remarks_friend_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_friend_remarks
    ADD CONSTRAINT user_friend_remarks_friend_user_id_fkey FOREIGN KEY (friend_user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: user_friend_remarks user_friend_remarks_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_friend_remarks
    ADD CONSTRAINT user_friend_remarks_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: user_geolocations user_geolocations_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_geolocations
    ADD CONSTRAINT user_geolocations_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: user_heartbeat_logs user_heartbeat_logs_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_heartbeat_logs
    ADD CONSTRAINT user_heartbeat_logs_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: user_login_history user_login_history_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_login_history
    ADD CONSTRAINT user_login_history_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: user_roles user_roles_assigned_by_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_roles
    ADD CONSTRAINT user_roles_assigned_by_fkey FOREIGN KEY (assigned_by) REFERENCES public.admin_users(id) ON DELETE SET NULL;


--
-- Name: user_roles user_roles_role_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_roles
    ADD CONSTRAINT user_roles_role_id_fkey FOREIGN KEY (role_id) REFERENCES public.roles(id) ON DELETE CASCADE;


--
-- Name: user_roles user_roles_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_roles
    ADD CONSTRAINT user_roles_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: user_room_pins user_room_pins_room_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_room_pins
    ADD CONSTRAINT user_room_pins_room_id_fkey FOREIGN KEY (room_id) REFERENCES public.rooms(id) ON DELETE CASCADE;


--
-- Name: user_room_pins user_room_pins_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_room_pins
    ADD CONSTRAINT user_room_pins_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--

