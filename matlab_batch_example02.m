function [] = example2untitled(arg1, arg2)

fprintf('This is a test for comman-line matlab shenanigans.\n')
disp(arg1{2})
disp(arg2)

output = arg2 * exp(-1) ^ 15;
disp(output)