-- Allow task creators to delete their own custom tasks
CREATE POLICY "tasks_delete" ON public.tasks
  FOR DELETE USING (
    auth.uid() = created_by AND is_builtin = false
  );
