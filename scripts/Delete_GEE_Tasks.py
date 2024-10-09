import ee
ee.Authenticate()

# Initialize Earth Engine
ee.Initialize()

# Get all the tasks in the Earth Engine Task Manager
task_list = ee.batch.Task.list()

# Loop through tasks and print their status
for task in task_list:
    print(f"Task ID: {task.id}, State: {task.state}")

# Delete failed tasks
for task in task_list:
    if task.state in ['FAILED', 'CANCELLED']:
        print(f"Deleting Task: {task.id}, State: {task.state}")
        task.cancel()
