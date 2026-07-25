import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
} from 'typeorm';

@Entity('deleted_categories_history')
export class DeletedCategoryHistory {
  @PrimaryGeneratedColumn()
  id: number;

  @Column({ name: 'category_id' })
  categoryId: number;

  @Column({ name: 'category_name' })
  categoryName: string;

  @Column({ type: 'text', nullable: true })
  details: string;

  @Column({ name: 'admin_name', default: 'Admin' })
  adminName: string;

  @CreateDateColumn({ name: 'deleted_at' })
  deletedAt: Date;
}
