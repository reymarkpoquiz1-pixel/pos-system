import { Injectable, OnModuleInit, ConflictException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, DataSource } from 'typeorm';
import { User, UserRole } from './entities/user.entity';
import { Staff } from '../staff/entities/staff.entity';
import { Customer } from '../customers/entities/customer.entity';
import * as bcrypt from 'bcrypt';
import * as fs from 'fs';
import * as path from 'path';

@Injectable()
export class UsersService implements OnModuleInit {
  constructor(
    @InjectRepository(User)
    private usersRepository: Repository<User>,
    @InjectRepository(Staff)
    private staffRepository: Repository<Staff>,
    private dataSource: DataSource,
  ) {}

  async onModuleInit() {
    await this.seedAdmin();
  }

  async seedAdmin() {
    const admin = await this.findByUsername('admin');
    if (!admin) {
      console.log('Seeding default admin user...');
      await this.create({
        username: 'admin',
        password: 'password123',
        role: UserRole.ADMIN,
      });
    }
  }

  async findByUsername(username: string): Promise<User | null> {
    return this.usersRepository.findOne({
      where: { username },
      relations: { staff: true },
    });
  }

  async create(userData: Partial<User>): Promise<User> {
    const hashedPassword = await bcrypt.hash(userData.password, 10);
    const user = this.usersRepository.create({
      ...userData,
      password: hashedPassword,
    });
    return this.usersRepository.save(user);
  }

  async register(registrationDto: any) {
    const existingUser = await this.findByUsername(registrationDto.username);
    if (existingUser) {
      throw new ConflictException('Username already exists');
    }

    const hashedPassword = await bcrypt.hash(registrationDto.password, 10);

    return await this.dataSource.transaction(async (manager) => {
      const user = manager.create(User, {
        username: registrationDto.username,
        password: hashedPassword,
        role: UserRole.USER,
        email: registrationDto.email,
      });
      const savedUser = await manager.save(user);

      const customer = manager.create(Customer, {
        user: savedUser,
        name: registrationDto.name || registrationDto.username,
        email: registrationDto.email,
        phone: registrationDto.phone,
      });
      await manager.save(customer);

      return { success: true, message: 'User account created successfully!' };
    });
  }

  async registerStaff(data: any) {
    const {
      username,
      password,
      first_name,
      last_name,
      gender,
      terminal_id,
      role,
      admin_name,
      image,
    } = data;

    const existingUser = await this.findByUsername(username);
    if (existingUser) {
      throw new ConflictException('Username already exists');
    }

    const hashedPassword = await bcrypt.hash(password, 10);

    return await this.dataSource.transaction(async (manager) => {
      // 1. Create User
      const user = manager.create(User, {
        username,
        password: hashedPassword,
        role: (role as UserRole) || UserRole.STAFF,
      });
      const savedUser = await manager.save(user);

      // 2. Handle Profile Image (Base64)
      let profileImage: string | undefined = undefined;
      if (image && image.toString().length > 0) {
        try {
          const fileName = `profile_${Date.now()}_${Math.random().toString(36).substring(7)}.png`;
          const uploadDir = path.join(process.cwd(), 'uploads');
          if (!fs.existsSync(uploadDir)) {
            fs.mkdirSync(uploadDir, { recursive: true });
          }
          const filePath = path.join(uploadDir, fileName);
          const base64Data = image.replace(/^data:image\/\w+;base64,/, '');
          fs.writeFileSync(filePath, Buffer.from(base64Data, 'base64'));
          profileImage = `uploads/${fileName}`;
        } catch (e) {
          console.error('Image upload failed:', e);
        }
      }

      // 3. Create Staff Info
      const staff = manager.create(Staff, {
        user: savedUser,
        firstName: first_name,
        lastName: last_name,
        gender: gender || 'Male',
        terminalId: terminal_id || '0',
        profileImage: profileImage,
        addedByName: admin_name || 'Admin',
      } as any);
      await manager.save(staff);

      return { success: true, message: 'Staff account created successfully!' };
    });
  }
}
