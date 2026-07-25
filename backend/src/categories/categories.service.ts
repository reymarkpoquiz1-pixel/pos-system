import {
  Injectable,
  ConflictException,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, DataSource, IsNull } from 'typeorm';
import { Category } from './entities/category.entity';
import { CategoryHistory } from './entities/category-history.entity';
import { DeletedCategoryHistory } from './entities/deleted-category-history.entity';
import { ActivityLogsService } from '../activity-logs/activity-logs.service';

@Injectable()
export class CategoriesService {
  constructor(
    @InjectRepository(Category)
    private categoriesRepository: Repository<Category>,
    @InjectRepository(CategoryHistory)
    private historyRepository: Repository<CategoryHistory>,
    @InjectRepository(DeletedCategoryHistory)
    private deletedHistoryRepository: Repository<DeletedCategoryHistory>,
    private activityLogsService: ActivityLogsService,
    private dataSource: DataSource,
  ) {}

  async addCategory(data: any, ip: string) {
    return await this.dataSource.transaction(async (manager) => {
      const { name, description, icon, parent_id, new_parent_name, admin_id } =
        data;

      // Handle parent
      let parentId = parent_id;
      if (new_parent_name) {
        let parent = await manager.findOne(Category, {
          where: { name: new_parent_name },
        });
        if (!parent) {
          parent = manager.create(Category, {
            name: new_parent_name,
            status: 'Active',
          });
          parent = await manager.save(parent);
        } else if (parent.status === 'Inactive') {
          parent.status = 'Active';
          await manager.save(parent);
        }
        parentId = parent.id;
      }

      // Check if exists
      const existing = await manager.findOne(Category, { where: { name } });
      if (existing) {
        if (existing.status === 'Inactive') {
          // Restore logic
          existing.status = 'Active';
          existing.description = description || existing.description;
          existing.icon = icon || existing.icon;
          existing.parentId = parentId || existing.parentId;
          const saved = await manager.save(existing);

          await manager.save(CategoryHistory, {
            categoryId: saved.id,
            categoryName: saved.name,
            action: 'Restored',
            details: `Category '${name}' reactivated during add operation.`,
            adminName: 'System Admin',
          } as any);

          return {
            success: true,
            message: 'Category reactivated',
            data: saved,
          };
        } else {
          throw new ConflictException('Category already exists and is Active');
        }
      }

      const category = manager.create(Category, {
        name,
        description,
        icon,
        parentId,
        status: 'Active',
      });
      const saved = await manager.save(category);

      await manager.save(CategoryHistory, {
        categoryId: saved.id,
        categoryName: saved.name,
        action: 'Added',
        details: `Created new category: ${name}.`,
        adminName: 'System Admin',
      } as any);

      await this.activityLogsService.log(
        admin_id,
        'ADD_CATEGORY',
        `Created category: ${name}`,
        ip,
      );

      return { success: true, data: saved };
    });
  }

  async updateCategory(data: any, ip: string) {
    return await this.dataSource.transaction(async (manager) => {
      const { id, name, description, icon, parent_id, admin_id } = data;
      const category = await manager.findOne(Category, { where: { id } });
      if (!category) throw new NotFoundException('Category not found');

      const oldName = category.name;
      const changes: string[] = [];

      if (name && name !== category.name) {
        // Conflict resolution: If name used by Inactive category, rename old one
        const conflicting = await manager.findOne(Category, {
          where: { name },
        });
        if (conflicting) {
          if (conflicting.status === 'Inactive' && conflicting.id !== id) {
            conflicting.name = `${conflicting.name}_old_${Date.now()}`;
            await manager.save(conflicting);
          } else if (conflicting.id !== id) {
            throw new ConflictException(
              'Name already in use by another active category',
            );
          }
        }
        changes.push(`Name changed from '${category.name}' to '${name}'`);
        category.name = name;
      }

      if (description !== undefined && description !== category.description) {
        changes.push(`Description updated`);
        category.description = description;
      }

      if (icon !== undefined && icon !== category.icon) {
        changes.push(`Icon updated`);
        category.icon = icon;
      }

      if (parent_id !== undefined && parent_id !== category.parentId) {
        changes.push(
          `Parent ID changed from ${category.parentId} to ${parent_id}`,
        );
        category.parentId = parent_id;
      }

      const saved = await manager.save(category);

      if (changes.length > 0) {
        await manager.save(CategoryHistory, {
          categoryId: saved.id,
          categoryName: saved.name,
          action: 'Updated',
          details: `Updated category details. ${changes.join(', ')}.`,
          adminName: 'System Admin',
        } as any);

        await this.activityLogsService.log(
          admin_id,
          'UPDATE_CATEGORY',
          `Updated category: ${oldName}`,
          ip,
        );
      }

      return { success: true, data: saved };
    });
  }

  async deleteCategory(id: number, adminId: number, ip: string) {
    return await this.dataSource.transaction(async (manager) => {
      const category = await manager.findOne(Category, { where: { id } });
      if (!category) throw new NotFoundException('Category not found');

      category.status = 'Inactive';
      await manager.save(category);

      await manager.save(CategoryHistory, {
        categoryId: category.id,
        categoryName: category.name,
        action: 'Deleted',
        details: `Category marked as Inactive.`,
        adminName: 'System Admin',
      } as any);

      await manager.save(DeletedCategoryHistory, {
        categoryId: category.id,
        categoryName: category.name,
        details: `Category soft deleted by admin.`,
      });

      await this.activityLogsService.log(
        adminId,
        'DELETE_CATEGORY',
        `Deleted category: ${category.name}`,
        ip,
      );

      return { success: true, message: 'Category deleted successfully' };
    });
  }

  async restoreCategory(id: number, adminId: number, ip: string) {
    return await this.dataSource.transaction(async (manager) => {
      const category = await manager.findOne(Category, { where: { id } });
      if (!category) throw new NotFoundException('Category not found');

      category.status = 'Active';
      await manager.save(category);

      await manager.delete(DeletedCategoryHistory, { categoryId: id });

      await manager.save(CategoryHistory, {
        categoryId: category.id,
        categoryName: category.name,
        action: 'Restored',
        details: `Category restored to Active status.`,
        adminName: 'System Admin',
      } as any);

      await this.activityLogsService.log(
        adminId,
        'RESTORE_CATEGORY',
        `Restored category: ${category.name}`,
        ip,
      );

      return { success: true, message: 'Category restored successfully' };
    });
  }

  async findAll() {
    const categories = await this.categoriesRepository.find({
      where: { parentId: IsNull(), status: 'Active' },
      relations: { children: true },
    });

    // Map children to sub_categories and ensure snake_case fields for Flutter
    return categories.map((cat) => ({
      ...cat,
      parent_id: cat.parentId,
      sub_categories: (cat.children || [])
        .filter((child) => child.status === 'Active')
        .map((child) => ({
          ...child,
          parent_id: child.parentId,
          created_at: child.createdAt,
          updated_at: child.updatedAt,
        })),
      created_at: cat.createdAt,
      updated_at: cat.updatedAt,
    }));
  }

  async getCategoryHistory(categoryId: number) {
    const history = await this.historyRepository.find({
      where: { categoryId },
      order: { createdAt: 'DESC' },
    });

    return history.map((h) => ({
      ...h,
      category_id: h.categoryId,
      category_name: h.categoryName,
      admin_name: h.adminName,
      created_at: h.createdAt,
    }));
  }
}
