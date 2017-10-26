
directories    = {};
directories{1} = '/Users/Max/Desktop/RcnnResults/DogAndPerson/';
directories{2} = '/Users/Max/Desktop/RcnnResults/DogNoPerson/';
directories{3} = '/Users/Max/Desktop/RcnnResults/NoDogNoPerson/';
directories{4} = '/Users/Max/Desktop/RcnnResults/PersonNoDog/';

output_directory = '/Users/Max/Desktop/Rcnnresults/Negative_all/';
if ~exist(output_directory,'dir')
    mkdir( output_directory );
end

new_name_schemes = {'DogAndPerson_%03d.csv'; 
                    'DogNoPerson_%03d.csv';
                    'NoDogNoPerson_%03d.csv';
                    'PersonNoDog_%03d.csv' };

sub_dirs = {'dog_walker','dog','leash'};
for sdi = 1:length(sub_dirs)
    if ~exist( fullfile(output_directory, sub_dirs{sdi}), 'dir' )
        mkdir( fullfile(output_directory, sub_dirs{sdi}) );
    end
end

for di = 1:length(directories)
for sdi = 1:length(sub_dirs)
    
    if ~exist( fullfile(output_directory, sub_dirs{sdi}), 'dir' )
        mkdir( fullfile(output_directory, sub_dirs{sdi}) );
    end

    cur_directory = directories{di};
    cur_directory = fullfile(cur_directory,sub_dirs{sdi});
    
    cur_new_name_scheme = new_name_schemes{di};
    
    dir_data = dir(fullfile(cur_directory,'*.csv'));

    for fi = 1:length(dir_data)

        fname_old = fullfile( cur_directory, dir_data(fi).name);
        %fprintf( fname_old );
        %fprintf( '\n' );

        fname_new = sprintf( fullfile( output_directory, sub_dirs{sdi}, cur_new_name_scheme), fi );
        %fprintf( fname_new );
        %fprintf( '\n' );

        success = copyfile(fname_old,fname_new);

        assert(success);
        
    end
    
    
fprintf('.');
end
fprintf('\n');
end

% 
