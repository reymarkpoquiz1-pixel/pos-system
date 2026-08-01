import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, DataSource, Not } from 'typeorm';
import { Staff, Gender } from './entities/staff.entity';
import { User, UserRole } from '../users/entities/user.entity';
import { ActivityLogsService } from '../activity-logs/activity-logs.service';
import { CloudinaryService } from '../cloudinary/cloudinary.service';
import * as bcrypt from 'bcrypt';
import * as fs from 'fs';
import * as path from 'path';

@Injectable()
export class StaffService {
  constructor(
    @InjectRepository(Staff)
    private staffRepository: Repository<Staff>,
    @InjectRepository(User)
    private userRepository: Repository<User>,
    private activityLogsService: ActivityLogsService,
    private cloudinaryService: CloudinaryService,
    private dataSource: DataSource,
  ) {}

  async getEmployees() {
    const users = await this.userRepository.find({
      where: { role: Not(UserRole.USER) },
      relations: { staff: true },
    });

    return users.map((u) => ({
      user_id: u.id,
      username: u.username,
      email: u.email,
      role: u.role,
      status: u.status,
      first_name: u.staff?.firstName || '',
      last_name: u.staff?.lastName || '',
      profile_image: u.staff?.profileImage || null,
      terminal_id: u.staff?.terminalId || '0',
      created_at: u.createdAt,
    }));
  }

  async updateStaff(data: any, ip: string) {
    return await this.dataSource.transaction(async (manager) => {
      const {
        user_id,
        username,
        role,
        password,
        first_name,
        last_name,
        gender,
        terminal_id,
        profile_image_base64,
        admin_id,
      } = data;

      const user = await manager.findOne(User, {
        where: { id: user_id },
        relations: { staff: true },
      });
      if (!user) throw new NotFoundException('User not found');

      // Update User
      if (username) user.username = username;
      if (role) user.role = role as UserRole;
      if (password) {
        user.password = await bcrypt.hash(password, 10);
      }
      await manager.save(user);

      // Update Staff
      let staff = user.staff;
      if (!staff) {
        staff = manager.create(Staff, { user });
      }

      if (first_name) staff.firstName = first_name;
      if (last_name) staff.lastName = last_name;
      if (gender) staff.gender = gender as Gender;
      if (terminal_id) staff.terminalId = terminal_id;

      // Handle Image (Cloudinary)
      if (profile_image_base64) {
        try {
          const uploadRes = await this.cloudinaryService.uploadBase64(
            profile_image_base64,
            'staff_profiles',
          );
          staff.profileImage = uploadRes.secure_url;
        } catch (e) {
          console.error('Update Image upload failed:', e);
        }
      }

      await manager.save(staff);

      await this.activityLogsService.log(
        admin_id,
        'UPDATE_STAFF',
        `Updated staff member: ${user.username}`,
        ip,
      );

      return { success: true, message: 'Staff updated successfully' };
    });
  }

  async deleteStaff(userId: number, adminId: number, ip: string) {
    return await this.dataSource.transaction(async (manager) => {
      const user = await manager.findOne(User, {
        where: { id: userId },
        relations: { staff: true },
      });
      if (!user) throw new NotFoundException('User not found');

      // Soft delete by setting role to User and disabling or similar?
      // Requirement says "Hard or soft delete staff account (to match original intention)".
      // Previous logic might have just deleted it. Let's do a hard delete if it's an employee account.

      const username = user.username;

      if (user.staff) {
        await manager.remove(user.staff);
      }
      await manager.remove(user);

      await this.activityLogsService.log(
        adminId,
        'DELETE_STAFF',
        `Deleted staff member: ${username}`,
        ip,
      );

      return { success: true, message: 'Staff deleted successfully' };
    });
  }

  async uploadProfileImage(
    userId: number,
    file: Express.Multer.File,
    ip: string,
  ) {
    const user = await this.userRepository.findOne({
      where: { id: userId },
      relations: { staff: true },
    });
    if (!user) throw new NotFoundException('User not found');

    const uploadRes = await this.cloudinaryService.uploadFile(file);

    let staff = user.staff;
    if (!staff) {
      staff = this.staffRepository.create({ user });
    }

    staff.profileImage = uploadRes.secure_url;
    await this.staffRepository.save(staff);

    await this.activityLogsService.log(
      userId,
      'UPLOAD_PROFILE_IMAGE',
      `Uploaded profile image for: ${user.username}`,
      ip,
    );

    return {
      success: true,
      message: 'Profile image uploaded successfully',
      profile_image: uploadRes.secure_url,
    };
  }
}
