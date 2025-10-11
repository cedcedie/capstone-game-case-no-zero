extends Node

var tasks = {
	"go_explore": false,  # example task
}

func set_task_done(task_name: String):
	if tasks.has(task_name):
		tasks[task_name] = true
		print("Task '%s' completed!" % task_name)
	else:
		print("Task '%s' does not exist!" % task_name)

func is_task_done(task_name: String) -> bool:
	return tasks.get(task_name, false)
