import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  OneToOne,
} from 'typeorm';
import { Staff } from '../../staff/entities/staff.entity';

export enum UserRole {
  ADMIN = 'Admin',
  STAFF = 'Staff',
  USER = 'User',
}

export enum UserStatus {
  VERIFIED = 'Verified',
  PENDING = 'Pending',
  SUSPENDED = 'Suspended',
}

@Entity('users')
export class User {
  @PrimaryGeneratedColumn()
  id!: number;

  @Column({ unique: true })
  username!: string;

  @Column({ unique: true, nullable: true })
  email!: string;

  @Column()
  password!: string;

  @Column({
    type: 'enum',
    enum: UserRole,
    default: UserRole.USER,
  })
  role!: UserRole;

  @Column({ name: 'branch_id', default: 1 })
  branchId!: number;

  @Column({
    type: 'enum',
    enum: UserStatus,
    default: UserStatus.VERIFIED,
  })
  status!: UserStatus;

  @Column({ name: 'is_2fa_enabled', default: false })
  is2faEnabled!: boolean;

  @Column({ name: 'two_factor_secret', nullable: true })
  twoFactorSecret!: string;

  @CreateDateColumn({ name: 'created_at' })
  createdAt!: Date;

  @OneToOne(() => Staff, (staff) => staff.user)
  staff!: Staff;
}
