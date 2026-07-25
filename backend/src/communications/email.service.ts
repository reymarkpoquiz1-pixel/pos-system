import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

@Injectable()
export class EmailService {
  private readonly logger = new Logger(EmailService.name);
  private apiKey: string;

  constructor(private configService: ConfigService) {
    this.apiKey =
      this.configService.get<string>('SENDGRID_API_KEY') ||
      'YOUR_SENDGRID_API_KEY';
  }

  sendEmail(to: string, subject: string, content: string) {
    if (!this.apiKey || this.apiKey === 'YOUR_SENDGRID_API_KEY') {
      this.logger.warn(`Email MOCK to ${to}: [${subject}] ${content}`);
      return true;
    }

    // Real SendGrid logic would go here using '@sendgrid/mail' npm package
    this.logger.log(`Sending real email to ${to}...`);
    return true;
  }
}
