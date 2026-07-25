import { Module, Global } from '@nestjs/common';
import { SMSService } from './sms.service';
import { EmailService } from './email.service';

@Global()
@Module({
  providers: [SMSService, EmailService],
  exports: [SMSService, EmailService],
})
export class CommunicationsModule {}
