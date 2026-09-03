# スキーマの投入。
#
# なぜRailsのマイグレーションではないのか:
# 表の定義の正本は web/supabase/schema.sql（Next.js版と共有）で、
# Rails側に db/migrate を持たない方針にしている。
# RDSは外部から接続できない設定（publicly_accessible = false）なので、
# 手元からpsqlで流すことができない。VPC内で動くこのコンテナ自身に流させる。
#
# 冪等性: schema.sql は create table if not exists / create or replace で書かれており、
# 何度実行しても同じ結果になる。起動のたびに走っても問題ない。
namespace :db do
  desc "db/bootstrap/*.sql を順に実行してスキーマを用意する"
  task bootstrap: :environment do
    files = Dir[Rails.root.join("db/bootstrap/*.sql")].sort
    if files.empty?
      warn "db/bootstrap にSQLがない。イメージのビルド時に取り込めていない可能性がある"
      exit 1
    end

    files.each do |path|
      puts "適用: #{File.basename(path)}"
      ActiveRecord::Base.connection.execute(File.read(path))
    end
    puts "スキーマの投入が完了"
  end
end
