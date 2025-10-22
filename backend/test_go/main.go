package main

import (
	"log"
	"net/http"

	"github.com/gin-gonic/gin"
)

func setupRouter() *gin.Engine {
	router := gin.Default()

	router.GET("/healthz", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{
			"status": "ok",
		})
	})

	return router
}

func main() {
	engine := setupRouter()
	if err := engine.Run(":60001"); err != nil {
		log.Fatalf("启动 Gin 服务失败: %v", err)
	}
}
