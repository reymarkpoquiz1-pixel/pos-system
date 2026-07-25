import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  ManyToOne,
  JoinColumn,
} from 'typeorm';
import { User } from '../../users/entities/user.entity';

@Entity('category_history')
export class CategoryHistory {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ name: 'category_id', nullable: true })
  categoryId: number;

  @Column({ name: 'category_name', nullable: true })
  categoryName: string;

  @Column()
  action: string;

  @Column({ type: 'text', nullable: true })
  details: string;

  @ManyToOne(() => User, { nullable: true, onDelete: 'SET NULL' })
  @JoinColumn({ name: 'user_id' })
  user: User;

  @Column({ name: 'admin_name', default: 'Admin' })
  adminName: string;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;
}
