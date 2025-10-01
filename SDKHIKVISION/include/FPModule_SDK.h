#ifndef __FPMODULE_SDK_H__
#define __FPMODULE_SDK_H__

/* ��������ֵ���� */
#define FP_SUCCESS              0       // ִ�гɹ�
#define FP_CONNECTION_ERR       1       // ͨ��ʧ��
#define FP_TIMEOUT              2       // �ɼ���ʱ
#define FP_ENROLL_FAIL          3       // ¼��ָ��ʧ��
#define FP_PARAM_ERR            4       // ��������
#define FP_EXTRACT_FAIL         5       // ��ȡ����ʧ��
#define FP_MATCH_FAIL           6       // �ȶ�����ʧ��
#define FP_FTP_MAX				512     // ������С
#define FP_IMAGE_WIDTH			256		
#define FP_IMAGE_HEIGHT			360		
#define FP_BMP_HEADER			1078

/* ��Ϣ���Ͷ��� */
typedef enum {
    FP_MSG_PRESS_FINGER,                // ¼��ָ�� ��ʾ����ָ
    FP_MSG_RISE_FINGER,                 // ¼��ָ�� ��ʾ̧��ָ
    FP_MSG_ENROLL_TIME,                 // ¼��ָ�� ������ʾ
    FP_MSG_CAPTURED_IMAGE,              // ¼��ָ�� ͼ����               
}FP_MSG_TYPE_T;

/* ͼ�������ݸ�ʽ����*/
typedef struct {
    int dwWidth;
    int dwHeight;
    unsigned char *pbyImage;
}FP_IMAGE_DATA;

/* ��Ϣ���������� */
typedef void (__stdcall *FpMessageHandler)(FP_MSG_TYPE_T enMsgType, void *pMsgData);


/* �����ϰ汾�ӿ� */
#define OpenDevice      FPModule_OpenDevice
#define CloseDevice     FPModule_CloseDevice
#define FPEnroll        FPModule_FpEnroll
#define GetQuality      FPModule_GetQuality
#define GetDeviceInfo   FPModule_GetDeviceInfo
#define GetSDKVersion   FPModule_GetSDKVersion


/** @func   : FPModule_OpenDevice
 *  @brief  : �����豸
 *  @param  : None
 *  @return : 0->���ӳɹ� 1->ͨ��ʧ��
 */
int __stdcall FPModule_OpenDevice(void);


/** @func   : FPModule_CloseDevice
 *  @brief  : �Ͽ��豸
 *  @param  : None
 *  @return : 0->�Ͽ��ɹ� 1->ͨ��ʧ��
 */
int __stdcall FPModule_CloseDevice(void);


/** @func   : FPModule_DetectFinger
 *  @brief  : ���ָ������״̬
 *  @param  : pdwFpstatus[out] -> 0:��ָ������  1:��ָ������
 *  @return : 0->ִ�гɹ� 1->ͨ��ʧ��
 */
int __stdcall FPModule_DetectFinger(int *pdwFpstatus);


/** @func   : FPModule_CaptureImage
 *  @brief  : �ɼ�ָ��ͼ��
 *  @param  : pbyImageData[out] -> ָ��ͼ�����ݣ����ݳ���Ϊ ͼ���� x ͼ��߶ȣ�
 *            pdwWidth[out]     -> ָ��ͼ����
 *            pdwHeight[out]    -> ָ��ͼ��߶�
 *  @return : 0->ִ�гɹ� 1->ͨ��ʧ��
 */
int __stdcall FPModule_CaptureImage(unsigned char *pbyImageData, int *pdwWidth, int *pdwHeight);


/** @func   : FPModule_SetTimeout
 *  @brief  : ���òɼ���ʱʱ��
 *  @param  : dwSecond[in] -> ��ʱʱ��(��λ����) ������ֵ��1����60��
 *  @return : 0->ִ�гɹ� 1->ͨ��ʧ�� 
 */
int __stdcall FPModule_SetTimeout(int dwSecond);


/** @func   : FPModule_GetTimeout
 *  @brief  : ��ȡ�ɼ���ʱʱ��
 *  @param  : pdwSecond[out] -> ��ʱʱ�� ��λ����
 *  @return : 0->ִ�гɹ� 1->ͨ��ʧ�� 
 */
int __stdcall FPModule_GetTimeout(int *pdwSecond);


/** @func   : FPModule_SetCollectTimes
 *  @brief  : ���òɼ�����
 *  @param  : dwTimes[in] -> 0~4,0Ĭ��ģʽ��2~4�Σ���1~3�ɼ�����
 *  @return : 0->ִ�гɹ� 1->ͨ��ʧ��
 */
int __stdcall FPModule_SetCollectTimes(int dwTimes);


/** @func   : FPModule_GetCollectTimes
 *  @brief  : ��ȡ�ɼ�����
 *  @param  : pdwTimes[out] -> �ɼ�����
 *  @return : 0->ִ�гɹ� 1->ͨ��ʧ��
 */
int __stdcall FPModule_GetCollectTimes(int *pdwTimes);


/** @func   : FPModule_InstallMessageHandler
 *  @brief  : ������Ϣ�ص�����
 *  @param  : msgHandler[in] -> ��Ϣ������
 *  @return : 0->ִ�гɹ�
 */
int __stdcall FPModule_InstallMessageHandler(FpMessageHandler msgHandler);


/** @func   : FPModule_FpEnroll
 *  @brief  : ¼��ָ��
 *  @param  : pbyFpTemplate[out] -> ָ��ģ��(512�ֽ�)
 *  @return : 0->ִ�гɹ� 1->ͨ��ʧ�� 2->�ɼ���ʱ 3->¼��ʧ��
 */
int __stdcall FPModule_FpEnroll(unsigned char *pbyFpTemplate);


/** @func   : FPModule_GetQuality
 *  @brief  : ��ȡָ��ģ����������
 *  @param  : pbyFpTemplate[in] -> ָ��ģ��(512�ֽ�)
 *  @return : ָ��ģ�����(0~100) ����Խ�ߣ���ʾģ�������Խ��
 */
int __stdcall FPModule_GetQuality(unsigned char *pbyFpTemplate);


/** @func   : FPModule_MatchTemplate
 *  @brief  : �ȶ���öָ��ģ��
 *  @param  : pbyFpTemplate1[in] -> ָ��ģ��1(512�ֽ�)
 *            pbyFpTemplate2[in] -> ָ��ģ��2(512�ֽ�)
 *            dwSecurityLevel[in] -> ��ȫ�ȼ���1~5��
 *  @return : 0->�ȶԳɹ� 6->�ȶ�ʧ�� 4->��������
 */
int __stdcall FPModule_MatchTemplate(unsigned char *pbyFpTemplate1, unsigned char *pbyFpTemplate2, int dwSecurityLevel);


/** @func   : FPModule_GetDeviceInfo
 *  @brief  : ��ȡָ�Ʋɼ��ǰ汾��Ϣ
 *  @param  : pbyDeviceInfo[out] -> ָ�Ʋɼ��ǰ汾��Ϣ(64�ֽ�)
 *  @return : 0->ִ�гɹ� 1->ͨ��ʧ�� 
 */
int __stdcall FPModule_GetDeviceInfo(char *pbyDeviceInfo);


/** @func   : FPModule_GetSDKVersion
 *  @brief  : ��ȡָ�Ʋɼ���SDK�汾��Ϣ
 *  @param  : pbySDKVersion[out] -> ָ�Ʋɼ���SDK�汾��Ϣ(64�ֽ�)
 *  @return : 0->ִ�гɹ�
 */
int __stdcall FPModule_GetSDKVersion(char *pbySDKVersion);


#endif
