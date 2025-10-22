package main

import (
	"bufio"
	"context"
	"errors"
	"flag"
	"fmt"
	"os"
	"path/filepath"
	"runtime"
	"strconv"
	"strings"
	"time"

	"github.com/jackc/pgx/v5"
)

func loadSQL(path string) (string, error) {
	info, err := os.Stat(path)
	if err != nil {
		if errors.Is(err, os.ErrNotExist) {
			return "", fmt.Errorf("未找到 SQL 文件：%s", path)
		}
		return "", err
	}
	if info.IsDir() {
		return "", fmt.Errorf("SQL 路径指向目录：%s", path)
	}

	data, err := os.ReadFile(path)
	if err != nil {
		return "", err
	}
	return string(data), nil
}

func resetDatabase(ctx context.Context, conn *pgx.Conn, sqlText string) error {
	var dbName string
	if err := conn.QueryRow(ctx, "SELECT current_database()").Scan(&dbName); err != nil {
		return fmt.Errorf("获取当前数据库名称失败：%w", err)
	}
	fmt.Printf("已连接数据库：%s\n", dbName)

	fmt.Println("清空 public schema ...")
	statements := []string{
		"DROP SCHEMA IF EXISTS public CASCADE;",
		"CREATE SCHEMA public;",
		"GRANT ALL ON SCHEMA public TO CURRENT_USER;",
		"GRANT ALL ON SCHEMA public TO public;",
	}
	for _, stmt := range statements {
		if _, err := conn.Exec(ctx, stmt); err != nil {
			return fmt.Errorf("执行语句失败（%s）：%w", stmt, err)
		}
	}

	fmt.Println("执行全量初始化脚本 ...")
	if err := execSQLScript(ctx, conn, sqlText); err != nil {
		return fmt.Errorf("执行 SQL 脚本失败：%w", err)
	}

	fmt.Println("数据库重置并初始化完成。")
	return nil
}

func execSQLScript(ctx context.Context, conn *pgx.Conn, sqlText string) error {
	multi := conn.PgConn().Exec(ctx, sqlText)
	_, err := multi.ReadAll()
	return err
}

func loadDSNFromEnvFile(customPath string) (string, string, error) {
	var candidates []string
	if customPath != "" {
		candidates = append(candidates, customPath)
	}
	if scriptEnv := envPathRelativeToSource(); scriptEnv != "" {
		candidates = append(candidates, scriptEnv)
	}
	candidates = append(candidates, "backend/.env", "../.env", ".env")

	for _, candidate := range candidates {
		if candidate == "" {
			continue
		}
		path := candidate
		if !filepath.IsAbs(path) {
			absPath, err := filepath.Abs(candidate)
			if err != nil {
				continue
			}
			path = absPath
		}
		data, err := os.ReadFile(path)
		if err != nil {
			continue
		}
		if dsn := extractDatabaseURL(string(data)); dsn != "" {
			return dsn, path, nil
		}
	}

	if customPath != "" {
		return "", "", fmt.Errorf("未能从指定 .env 文件读取 DATABASE_URL：%s", customPath)
	}
	return "", "", errors.New("未能从 backend/.env 读取到 DATABASE_URL，请确认配置")
}

func envPathRelativeToSource() string {
	_, file, _, ok := runtime.Caller(0)
	if !ok {
		return ""
	}
	return filepath.Join(filepath.Dir(file), "..", ".env")
}

func extractDatabaseURL(content string) string {
	scanner := bufio.NewScanner(strings.NewReader(content))
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		parts := strings.SplitN(line, "=", 2)
		if len(parts) != 2 {
			continue
		}
		key := strings.TrimSpace(parts[0])
		if key != "DATABASE_URL" {
			continue
		}
		value := strings.TrimSpace(parts[1])
		if len(value) > 0 && (value[0] == '"' || value[0] == '\'') {
			if unquoted, err := strconv.Unquote(value); err == nil {
				value = unquoted
			}
		}
		return value
	}
	return ""
}

type arguments struct {
	dsn     string
	sqlPath string
	dryRun  bool
	envPath string
}

func parseArgs() (*arguments, error) {
	dsnFlag := flag.String("dsn", "", "PostgreSQL 连接串，默认读取环境变量 DATABASE_URL")
	sqlFlag := flag.String("sql", "all.sql", "全量初始化 SQL 文件路径（默认：当前目录下 all.sql）")
	dryRunFlag := flag.Bool("dry-run", false, "仅检查配置与 SQL 文件，不真正连接数据库")
	envFileFlag := flag.String("env-file", "", "自定义 .env 文件路径，默认读取 backend/.env")
	flag.Parse()

	dsn := strings.TrimSpace(*dsnFlag)
	var envPath string
	if dsn == "" {
		dsn = strings.TrimSpace(os.Getenv("DATABASE_URL"))
	}
	if dsn == "" {
		var err error
		dsn, envPath, err = loadDSNFromEnvFile(strings.TrimSpace(*envFileFlag))
		if err != nil {
			return nil, err
		}
	}

	absPath, err := filepath.Abs(*sqlFlag)
	if err != nil {
		return nil, fmt.Errorf("解析 SQL 文件路径失败：%w", err)
	}

	return &arguments{
		dsn:     dsn,
		sqlPath: absPath,
		dryRun:  *dryRunFlag,
		envPath: envPath,
	}, nil
}

func main() {
	args, err := parseArgs()
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}

	sqlText, err := loadSQL(args.sqlPath)
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}

	if args.dryRun {
		fmt.Println("Dry-run 模式：不会连接数据库。")
		fmt.Printf("连接串：%s\n", args.dsn)
		fmt.Printf("SQL 文件：%s\n", args.sqlPath)
		if args.envPath != "" {
			fmt.Printf(".env 文件：%s\n", args.envPath)
		}
		lineCount := 0
		if len(sqlText) > 0 {
			lineCount = strings.Count(sqlText, "\n") + 1
		}
		fmt.Printf("SQL 大小：%d 行\n", lineCount)
		return
	}

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Minute)
	defer cancel()

	conn, err := pgx.Connect(ctx, args.dsn)
	if err != nil {
		fmt.Fprintf(os.Stderr, "连接数据库失败：%v\n", err)
		os.Exit(1)
	}
	defer conn.Close(context.Background())

	if err := resetDatabase(ctx, conn, sqlText); err != nil {
		fmt.Fprintf(os.Stderr, "%v\n", err)
		os.Exit(1)
	}
}
