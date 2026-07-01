import re

with open('qrpay_sdk_android/android/src/main/kotlin/com/example/qrpay_sdk/CameraPipeline.kt', 'r') as f:
    content = f.read()

old_fps = """if (frameCount % 3 != 0) {
                imageProxy.close()
                return
            }"""
new_fps = """if (frameCount % 3 != 0) {
                imageProxy.close()
                isProcessing.set(false)
                return
            }"""
content = content.replace(old_fps, new_fps)

with open('qrpay_sdk_android/android/src/main/kotlin/com/example/qrpay_sdk/CameraPipeline.kt', 'w') as f:
    f.write(content)

