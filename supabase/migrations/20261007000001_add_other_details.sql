-- เพิ่มคอลัมน์ other_details สำหรับเก็บรายละเอียดเพิ่มเติม (เช่น กรณีเลือกแพลตฟอร์มหรือสาเหตุเป็น 'อื่นๆ')
alter table public.cod_reports
  add column if not exists other_details text null;
