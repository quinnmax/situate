fn = {};
fn{end+1} = '~/box_350_split_01_2016.07.20.18.50.16.mat';     
fn{end+1} = '~/box_350_split_02_2016.07.20.21.40.45.mat';
fn{end+1} = '/u/eroche/box_350_split_03_2016.07.21.00.21.23.mat';
fn{end+1} = '/u/eroche/box_350_split_04_2016.07.21.02.56.21.mat';
fn{end+1} = '/u/eroche/box_350_split_05_2016.07.21.05.38.53.mat';
fn{end+1} = '/u/eroche/box_350_split_06_2016.07.21.08.28.26.mat';
curv = zeros(1000,1);
for i = 1:6
	load (fn{i});
	res = zeros(50,1);
	for k = 1:50
		res(k) = workspace_entry_event_logs{k}{end,1};
	end
	batch = zeros(1000,1);
	for j =1:1000
		batch(j) = length(find(res < j));
	end 
	curv = curv + batch;
end

