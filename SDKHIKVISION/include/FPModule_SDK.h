#ifndef __FPMODULE_SDK_H__
#define __FPMODULE_SDK_H__

/* 函数返回值定义 */
#define FP_SUCCESS              0       // 执行成功
#define FP_CONNECTION_ERR       1       // 通信失败
#define FP_TIMEOUT              2       // 采集超时
#define FP_ENROLL_FAIL          3       // 录入指纹失败
#define FP_PARAM_ERR            4       // 参数错误
#define FP_EXTRACT_FAIL         5       // 提取特征失败
#define FP_MATCH_FAIL           6       // 比对特征失败
#define FP_FTP_MAX				512     // 特征大小
#define FP_IMAGE_WIDTH			256		
#define FP_IMAGE_HEIGHT			360		
#define FP_BMP_HEADER			1078

/* 消息类型定义 */
typedef enum {
    FP_MSG_PRESS_FINGER,                // 录入指纹 提示按手指
    FP_MSG_RISE_FINGER,                 // 录入指纹 提示抬手指
    FP_MSG_ENROLL_TIME,                 // 录入指纹 次数提示
    FP_MSG_CAPTURED_IMAGE,              // 录入指纹 图像反馈               
}FP_MSG_TYPE_T;

/* 图像反馈数据格式定义*/
typedef struct {
    int dwWidth;
    int dwHeight;
    unsigned char *pbyImage;
}FP_IMAGE_DATA;

/* 消息处理函数定义 */
typedef void (__stdcall *FpMessageHandler)(FP_MSG_TYPE_T enMsgType, void *pMsgData);


/* 兼容老版本接口 */
#define OpenDevice      FPModule_OpenDevice
#define CloseDevice     FPModule_CloseDevice
#define FPEnroll        FPModule_FpEnroll
#define GetQuality      FPModule_GetQuality
#define GetDeviceInfo   FPModule_GetDeviceInfo
#define GetSDKVersion   FPModule_GetSDKVersion


/** @func   : FPModule_OpenDevice
 *  @brief  : 连接设备
 *  @param  : None
 *  @return : 0->连接成功 1->通信失败
 */
int __stdcall FPModule_OpenDevice(void);


/** @func   : FPModule_CloseDevice
 *  @brief  : 断开设备
 *  @param  : None
 *  @return : 0->断开成功 1->通信失败
 */
int __stdcall FPModule_CloseDevice(void);


/** @func   : FPModule_DetectFinger
 *  @brief  : 检测指纹输入状态
 *  @param  : pdwFpstatus[out] -> 0:无指纹输入  1:有指纹输入
 *  @return : 0->执行成功 1->通信失败
 */
int __stdcall FPModule_DetectFinger(int *pdwFpstatus);


/** @func   : FPModule_CaptureImage
 *  @brief  : 采集指纹图像
 *  @param  : pbyImageData[out] -> 指纹图像数据（数据长度为 图像宽度 x 图像高度）
 *            pdwWidth[out]     -> 指纹图像宽度
 *            pdwHeight[out]    -> 指纹图像高度
 *  @return : 0->执行成功 1->通信失败
 */
int __stdcall FPModule_CaptureImage(unsigned char *pbyImageData, int *pdwWidth, int *pdwHeight);


/** @func   : FPModule_SetTimeout
 *  @brief  : 设置采集超时时间
 *  @param  : dwSecond[in] -> 超时时间(单位：秒) 可设置值：1秒至60秒
 *  @return : 0->执行成功 1->通信失败 
 */
int __stdcall FPModule_SetTimeout(int dwSecond);


/** @func   : FPModule_GetTimeout
 *  @brief  : 获取采集超时时间
 *  @param  : pdwSecond[out] -> 超时时间 单位：秒
 *  @return : 0->执行成功 1->通信失败 
 */
int __stdcall FPModule_GetTimeout(int *pdwSecond);


/** @func   : FPModule_SetCollectTimes
 *  @brief  : 设置采集次数
 *  @param  : dwTimes[in] -> 0~4,0默认模式（2~4次），1~3采集次数
 *  @return : 0->执行成功 1->通信失败
 */
int __stdcall FPModule_SetCollectTimes(int dwTimes);


/** @func   : FPModule_GetCollectTimes
 *  @brief  : 获取采集次数
 *  @param  : pdwTimes[out] -> 采集次数
 *  @return : 0->执行成功 1->通信失败
 */
int __stdcall FPModule_GetCollectTimes(int *pdwTimes);


/** @func   : FPModule_InstallMessageHandler
 *  @brief  : 设置消息回调函数
 *  @param  : msgHandler[in] -> 消息处理函数
 *  @return : 0->执行成功
 */
int __stdcall FPModule_InstallMessageHandler(FpMessageHandler msgHandler);


/** @func   : FPModule_FpEnroll
 *  @brief  : 录入指纹
 *  @param  : pbyFpTemplate[out] -> 指纹模板(512字节)
 *  @return : 0->执行成功 1->通信失败 2->采集超时 3->录入失败
 */
int __stdcall FPModule_FpEnroll(unsigned char *pbyFpTemplate);


/** @func   : FPModule_GetQuality
 *  @brief  : 获取指纹模板质量分数
 *  @param  : pbyFpTemplate[in] -> 指纹模板(512字节)
 *  @return : 指纹模板分数(0~100) 分数越高，表示模板的质量越好
 */
int __stdcall FPModule_GetQuality(unsigned char *pbyFpTemplate);


/** @func   : FPModule_MatchTemplate
 *  @brief  : 比对两枚指纹模板
 *  @param  : pbyFpTemplate1[in] -> 指纹模板1(512字节)
 *            pbyFpTemplate2[in] -> 指纹模板2(512字节)
 *            dwSecurityLevel[in] -> 安全等级（1~5）
 *  @return : 0->比对成功 6->比对失败 4->参数错误
 */
int __stdcall FPModule_MatchTemplate(unsigned char *pbyFpTemplate1, unsigned char *pbyFpTemplate2, int dwSecurityLevel);


/** @func   : FPModule_GetDeviceInfo
 *  @brief  : 获取指纹采集仪版本信息
 *  @param  : pbyDeviceInfo[out] -> 指纹采集仪版本信息(64字节)
 *  @return : 0->执行成功 1->通信失败 
 */
int __stdcall FPModule_GetDeviceInfo(char *pbyDeviceInfo);


/** @func   : FPModule_GetSDKVersion
 *  @brief  : 获取指纹采集仪SDK版本信息
 *  @param  : pbySDKVersion[out] -> 指纹采集仪SDK版本信息(64字节)
 *  @return : 0->执行成功
 */
int __stdcall FPModule_GetSDKVersion(char *pbySDKVersion);


#endif
