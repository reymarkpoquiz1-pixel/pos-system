import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { StaffService } from './staff.service';
import { StaffController } from './staff.controller';
import { Staff } from './entities/staff.entity';
import { User } from '../users/entities/user.entity';
import { ActivityLogsModule } from '../activity-logs/activity-logs.module';
import { CloudinaryModule } from '../cloudinary/cloudinary.module';

@Module({
  imports: [
    TypeOrmModule.forFeature([Staff, User]),
    ActivityLogsModule,
    CloudinaryModule,
  ],
  providers: [StaffService],
  controllers: [StaffController],
  exports: [StaffService],
})
export class StaffModule {}
