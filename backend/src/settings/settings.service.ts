import { Injectable, OnModuleInit } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, DataSource } from 'typeorm';
import { StoreSetting } from './entities/store-setting.entity';
import * as fs from 'fs';
import * as path from 'path';

@Injectable()
export class SettingsService implements OnModuleInit {
  constructor(
    @InjectRepository(StoreSetting)
    private readonly storeSettingRepository: Repository<StoreSetting>,
    private dataSource: DataSource,
  ) {}

  async onModuleInit() {
    const setting = await this.storeSettingRepository.findOne({
      where: { id: 1 },
    });
    if (!setting) {
      const defaultSetting = this.storeSettingRepository.create({
        id: 1,
        storeName: 'My POS Store',
        taxRate: 12.0,
      });
      await this.storeSettingRepository.save(defaultSetting);
    }
  }

  async getPublicSettings() {
    const settings = await this.storeSettingRepository.findOne({
      where: { id: 1 },
    });
    if (!settings) return null;

    return {
      id: settings.id,
      store_name: settings.storeName,
      logo_url: settings.logoUrl,
    };
  }

  async getStoreSettings() {
    const settings = await this.storeSettingRepository.findOne({ where: { id: 1 } });
    if (!settings) return null;

    return {
      ...settings,
      store_name: settings.storeName,
      logo_url: settings.logoUrl,
      tax_rate: settings.taxRate,
    };
  }

  async backupDatabase() {
    const backupDir = path.join(process.cwd(), 'backups');
    if (!fs.existsSync(backupDir)) {
      fs.mkdirSync(backupDir);
    }

    const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
    const fileName = `backup-${timestamp}.json`;
    const filePath = path.join(backupDir, fileName);

    // Simple JSON dump of all tables
    const tables = await this.dataSource.query(`
      SELECT table_name
      FROM information_schema.tables
      WHERE table_schema = 'public'
    `);

    const backupData: any = {};
    for (const table of tables) {
      const tableName = table.table_name;
      backupData[tableName] = await this.dataSource.query(
        `SELECT * FROM "${tableName}"`,
      );
    }

    fs.writeFileSync(filePath, JSON.stringify(backupData, null, 2));

    return {
      message: 'Database backup created successfully',
      file: fileName,
      path: filePath,
    };
  }
}
