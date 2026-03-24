import { post, type ApiResponse } from "./http";

interface FeedbackPayload {
  success?: boolean;
  message?: string;
}

export class FeedbackApi {
  static async submit(params: {
    content: string;
    contact?: string;
  }): Promise<ApiResponse<{ success: boolean; message: string }>> {
    const content = params.content.trim();
    if (!content) {
      return {
        code: 400,
        success: false,
        message: "反馈内容不能为空",
        data: null
      };
    }

    const requestBody: Record<string, unknown> = {
      content
    };
    const contact = params.contact?.trim();
    if (contact) {
      requestBody.contact = contact;
    }

    const response = await post<FeedbackPayload>("/feedbacks", requestBody);
    if (!response.success || !response.data) {
      return {
        ...response,
        data: null
      };
    }

    return {
      ...response,
      data: {
        success: typeof response.data.success === "boolean" ? response.data.success : response.success,
        message: response.data.message || response.message || "反馈提交成功"
      }
    };
  }
}
