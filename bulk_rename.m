path = '/Users/Max/Desktop/total support testing';
fn = dir( fullfile( path, '*.mat' ) );
fn = cellfun( @(x) fullfile( path, x ), {fn.name}, 'UniformOutput', false );

for fi = 1:length(fn)
    temp = load(fn{fi});
    new_fn = fullfile( path, [temp.p_condition.description '_' datestr(now,'yyyy.mm.dd.HH.MM.SS') '.mat' ]);
    save( new_fn, '-struct', 'temp');
    display(new_fn);
end
