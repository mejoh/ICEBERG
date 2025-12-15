function output = example(x)
fprintf("This is an example for terminal-based matlab...\n")
for i = 1:length(x)
    fprintf("Number is %i\n", i)
end

output = pwd;
disp(output)

%argName = input('Argument variable name: ', 's');
%argValue = evalin('caller', argName);
%disp(['Argument: ', num2str(argValue)]);