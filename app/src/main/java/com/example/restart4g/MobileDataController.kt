package com.example.restart4g

import rikka.shizuku.Shizuku

object MobileDataController {

    private fun toggleMobileData(enable: Boolean) {
        try {
            // 使用 Shizuku 执行 shell 命令来控制移动数据
            val command = if (enable) "svc data enable" else "svc data disable"
            Shizuku.newProcess(arrayOf("sh", "-c", command), null, null).waitFor()
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    fun restart4G() {
        toggleMobileData(false)
        Thread.sleep(2000) // 等待 2 秒
        toggleMobileData(true)
    }
}